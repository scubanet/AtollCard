# AtollCard M1 — Security Notes (Vex RLS Audit Gate)

Audit date: 2026-06-28
Scope: `supabase/migrations/0001`–`0007` against the running local stack
(`postgresql://postgres:postgres@127.0.0.1:54322/postgres`).
Auditor: Vex (Application Security Engineer).
Method: schema review + empirical exploit attempts under `anon` / `authenticated`
roles with simulated JWT claims. All checks ran inside rolled-back transactions.

Result: **PASS (DONE_WITH_CONCERNS)** — no CRITICAL/HIGH findings. Two LOW/MEDIUM
hardening items are recorded under *Findings / Risks*.

---

## 1. RLS enabled on every public table — CONFIRMED

```
select relname, relrowsecurity from pg_class
where relnamespace = 'public'::regnamespace and relkind='r';

   relname   | relrowsecurity
-------------+----------------
 cards       | t
 profiles    | t
 card_fields | t
 card_events | t
(4 rows)
```

All four public tables have `relrowsecurity = t`. Policy summary (verified via
`pg_policy`):

- `profiles` — SELECT/UPDATE restricted to `auth.uid() = id`. No INSERT policy:
  rows are created exclusively by the `handle_new_user` trigger (definer). No
  DELETE policy: removal happens only via `ON DELETE CASCADE` from `auth.users`.
- `cards` — SELECT/INSERT/UPDATE/DELETE all gated on `auth.uid() = owner_id`.
- `card_fields` — all four commands gated on ownership of the parent card via an
  `EXISTS` subquery against `cards.owner_id = auth.uid()`.
- `card_events` — **SELECT only**, restricted to the owner of the parent card.
  There is deliberately **no INSERT policy**; events are written solely through
  the `record_card_event` SECURITY DEFINER RPC. Direct `anon` INSERT was
  attempted and **blocked** by RLS ("new row violates row-level security
  policy"), so events cannot be forged or back-dated by clients.

---

## 2. SECURITY DEFINER functions — CONFIRMED (exactly three, all safe)

```
select proname, prosecdef from pg_proc
where pronamespace='public'::regnamespace and prosecdef;

      proname      | prosecdef
-------------------+-----------
 handle_new_user   | t
 get_public_card   | t
 record_card_event | t
(3 rows)
```

No other SECURITY DEFINER function exists in `public`. All three set
`search_path = public` explicitly, which neutralises search-path hijacking — the
standard definer-function attack vector.

### `handle_new_user` (0002)
AFTER INSERT trigger on `auth.users`. Inserts a `profiles` row for the new user
(`id`, optional `display_name` from user metadata). Touches only the new user's
own row; reads no other user's data; writes no privileged columns. Safe.

### `get_public_card(p_slug)` (0006)
`STABLE`, language `sql`. Filters
`where c.slug = p_slug and c.visibility = 'public' and c.is_active = true`.
Returns a fixed projection (`public_card` composite): display/title/company,
theme/accent/colors, three media URLs, and a JSON array of fields. It returns
**no** `owner_id`, no email of the account, no internal IDs, and never exposes
private or inactive cards. Empirically verified:
- `priv` (private) → `(null/denied)`
- `pub`  (public)  → returns the card
- `inact` (public but `is_active=false`) → `(null/denied)`

### `record_card_event(p_slug, p_type, p_coarse_geo)` (0006)
`plpgsql`. Resolves the target card with the **same** guard as `get_public_card`
(`slug = p_slug and visibility = 'public' and is_active = true`); if no public
active card matches, it returns early and inserts nothing. Otherwise it inserts
`(card_id, type, coarse_geo)` only. Empirically verified: calling it against a
private card recorded **0** events. The function is the only write path into
`card_events`, and it cannot be steered toward a non-public card.

Both public RPCs are granted `execute` to `anon, authenticated` — intentional,
since the public web profile is unauthenticated.

---

## 3. Anonymized-event design — CONFIRMED

`card_events` (0005) columns: `id`, `card_id`, `type`, `occurred_at`,
`coarse_geo`, `referrer`.

- **No IP address is stored.** No column exists for it; the RPC never receives or
  writes one.
- **`coarse_geo` is country-level only** by contract — it is a free-text param
  the caller supplies (e.g. an ISO country code). The DB stores whatever the edge
  passes; the documented contract is country-only. No lat/long, no city.
- **`referrer` is intended to be host-only.** Note: the M1 `record_card_event`
  signature does **not** populate `referrer` at all (it is left NULL), so no
  referrer data is currently captured. See Finding R-2.

This matches a privacy-by-default analytics posture: aggregate event types with
coarse geography, no per-visitor PII.

---

## 4. Storage bucket `card-media` (0007)

Bucket created with `public = true`. Policies:
- `card_media_public_read` — SELECT for **anyone** where `bucket_id = 'card-media'`.
- write/update/delete — restricted to the owner, keyed on the first path segment
  `(storage.foldername(name))[1] = auth.uid()::text`. Path contract is
  `<owner_id>/<card_id>/{cover|photo}`.

The owner-scoped write/update/delete policies are correct: a user can only mutate
objects under their own `auth.uid()` prefix. See Finding R-1 on public read.

---

## Findings / Risks

### R-1 — Public bucket exposes media of non-public cards — MEDIUM
`card-media` is a public bucket with unconditional public read. Media uploaded
for a card whose `visibility` is `private`/`unlisted` is still served at a stable,
publicly fetchable URL. The RPC layer correctly hides private *card data*, but the
*images* live in a separately-readable namespace and are not gated by card
visibility or `is_active`.

- **Impact:** anyone who knows or guesses an object URL can fetch a private
  card's cover/photo/logo. URLs embed two UUIDs (`owner_id`, `card_id`), so they
  are not enumerable — this is currently *security through unguessability*, not
  authorization. Severity is MEDIUM rather than HIGH because of the UUID entropy
  and because M1 surfaces media only for public cards.
- **Recommendation (do not fix in this gate):** for M2, either (a) keep media in a
  **private** bucket and serve public-card images via short-lived signed URLs
  minted by `get_public_card`, or (b) add a read policy that joins
  `storage.objects` → `cards` and requires `visibility='public' and is_active`.
  Option (a) is cleaner given the existing RPC boundary.

### R-2 — `referrer` column present but unused / contract drift — LOW
`card_events.referrer` exists but `record_card_event` never sets it. If a future
revision wires referrer through, it must store **host-only** (strip path, query,
and fragment) to honour the anonymized-event design in §3. Flagging now so the
contract is not silently violated later.

### R-3 — UPDATE policies omit `WITH CHECK` — LOW (hardening, not a vuln)
`profiles_update_own`, `cards_update_own`, and `card_fields_update_via_owner`
define a `USING` clause but no `WITH CHECK`. I tested whether this allows
ownership transfer / row migration:
- attempt to `update cards set owner_id = <other user>` → **blocked**
  ("new row violates row-level security policy").
- attempt to `update card_fields set card_id = <card I don't own>` → **blocked**.

This is expected Postgres behaviour: when `WITH CHECK` is omitted on an UPDATE
policy, the `USING` expression is re-applied to the *post-update* row, so the
ownership predicate already guards the new row. **No vulnerability.** Adding an
explicit `WITH CHECK` mirroring each `USING` is recommended purely for clarity
and defence-in-depth, so intent does not rely on the implicit fallback.

### Default table grants (informational, not a finding)
`anon`/`authenticated` hold broad table-level grants (INSERT/UPDATE/DELETE/…) on
all four tables — Supabase's default. These are **harmless** here because RLS is
enabled on every table and denies by default where no permissive policy exists
(proven by the blocked `card_events` direct insert). Grants without a matching
RLS policy grant nothing.

---

## Verdict

RLS is on for all public tables; the three SECURITY DEFINER functions are minimal,
search-path-pinned, and cannot leak non-public data; the event pipeline is
write-only through a guarded RPC and stores no PII. Gate result: **PASS** with two
tracked items (R-1 MEDIUM, R-2 LOW) for M2 and one LOW hardening note (R-3). No
code changed as part of this audit.
