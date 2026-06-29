# Kontakte-Empfang (Lead-Capture) — Design

**Datum:** 2026-06-28
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 2.** Besucher des öffentlichen Web-Profils hinterlässt seine Kontaktdaten; der Karten-Owner empfängt diese als „Connection"/Lead und sieht sie im Kontakte-Tab der App.

## Ziel
„Verbinden"-Formular auf `card.atoll-os.com/<slug>` (Name, E-Mail, Telefon, Firma, Nachricht) → anonym via `SECURITY DEFINER`-RPC als `connection` beim Owner gespeichert → iOS-Kontakte-Tab listet Leads (Liste + Detail mit tap-to-call/mail). Kein App-zu-App-Austausch, kein Geräte-Adressbuch-Export (spätere Runde).

## A. Backend (lokal + Prod `bhkeplfkuismwyfiqcga`)
Migration `0010_connections.sql`:
- Tabelle:
```sql
create table public.connections (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.cards(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  company text,
  note text,
  coarse_geo text,
  created_at timestamptz not null default now()
);
create index connections_card_id_idx on public.connections(card_id);
alter table public.connections enable row level security;
-- Owner liest Leads eigener Karten; KEIN Insert-Pfad (nur via RPC).
create policy "connections_select_via_owner" on public.connections for select
  using (exists (select 1 from public.cards c where c.id = connections.card_id and c.owner_id = auth.uid()));
```
- RPC:
```sql
create or replace function public.record_connection(
  p_slug text, p_name text, p_email text default null, p_phone text default null,
  p_company text default null, p_note text default null, p_coarse_geo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_card_id uuid;
begin
  if coalesce(trim(p_name), '') = '' then return; end if;
  select id into v_card_id from public.cards
    where slug = p_slug and visibility = 'public' and is_active = true;
  if v_card_id is null then return; end if;
  insert into public.connections (card_id, name, email, phone, company, note, coarse_geo)
  values (v_card_id, trim(p_name), p_email, p_phone, p_company, p_note, p_coarse_geo);
end; $$;
revoke execute on function public.record_connection(text,text,text,text,text,text,text) from public;
grant execute on function public.record_connection(text,text,text,text,text,text,text) to anon, authenticated;
```
(Anon-Grant gewollt — Web ist anonym. Supabase-Default-Privileg auf anon ist hier korrekt; explizit grant zur Klarheit.)
- pgTAP `supabase/tests/0005_connections_test.sql`: anon `record_connection` auf public Card → Owner sieht 1 Lead; private Card → 0; leerer Name → 0; RLS: Fremduser sieht Lead nicht.

Controller wendet `0010` auf lokal + Prod an und verifiziert live.

## B. Web
- `web/src/lib/connect.ts`: `recordConnection(client, slug, payload)` ruft `client.rpc('record_connection', {p_slug, p_name, p_email, p_phone, p_company, p_note})`. `payload`-Typ `ConnectPayload {name; email?; phone?; company?; note?}`. Validierung: `name` nicht-leer (sonst Fehler vor RPC); falls `email` gesetzt, simpler Format-Check (`/.+@.+\..+/`).
- `web/src/render.ts`: „Verbinden"-Button rendert ein `<form>` (5 Felder, `name` required). Submit ruft Consent-Gate (bestehendes `consent`-Modul) — Absender willigt in Speicherung seiner Daten ein —, dann `recordConnection`, dann Success-/Fehler-Text. HTML-Escaping wie im bestehenden Renderer.
- vitest: `connect.test.ts` (RPC-Param-Mapping, Name-Pflicht, E-Mail-Check); Render-Test, dass das Formular existiert.

## C. iOS (Kontakte-Tab)
- `AtollCard/Models/Connection.swift`: `struct Connection: Codable, Identifiable, Equatable` mit `id:UUID, cardId:UUID, name, email?, phone?, company?, note?, createdAt:Date` + snake_case CodingKeys (`card_id`, `created_at`). `JSONDecoder.atoll` braucht Datums-Strategie für `created_at` (ISO8601) — Decoder anpassen oder `created_at` als String halten. **Entscheidung:** `createdAt: Date`, `JSONDecoder.atoll` bekommt `.dateDecodingStrategy = .iso8601` (PostgREST liefert ISO8601). Bestehende Modelle haben kein Date-Feld → unkritisch.
- `AtollCard/Stores/ConnectionStoring.swift`: `protocol ConnectionStoring { func connections(forOwner ownerId: UUID) async throws -> [Connection] }`.
- `InMemoryConnectionStore` (Fake, seedbar) + `SupabaseConnectionStore` (`client.from("connections").select().order("created_at", ascending:false).execute().value` — RLS liefert nur eigene; `ownerId`-Param ignoriert/zur Symmetrie).
- `ConnectionsViewModel(store:ownerId:)`: `@Published connections`, `@Published errorMessage`, `load()`.
- `AppStores` + `connectionStore` (default `SupabaseConnectionStore()`, preview/test `InMemoryConnectionStore`).
- `ContactsView`: Placeholder → `@StateObject ConnectionsViewModel`, `.task { await vm.load() }`; Liste (Name fett, Firma + relatives Datum), Empty-State bleibt bei 0; `NavigationLink` → `ConnectionDetailView`.
- `ConnectionDetailView`: Name/Firma/Notiz; E-Mail-Zeile öffnet `mailto:`, Telefon-Zeile `tel:` (via `Link`/`openURL`, `tel:` nur iOS sinnvoll — `#if os(iOS)`).
- `RootTabView`/`AtollCardApp`: `connectionStore` + `ownerId` an `ContactsView` durchreichen.
- XCTest: `InMemoryConnectionStoreTests`, `ConnectionsViewModelTests` (load füllt Liste; Fehler setzt errorMessage).

## D. Fehler/DSGVO/Security
- Web: Name-Pflicht клиент- + serverseitig (RPC no-op bei leer). Consent-Gate vor Submit. Erfolg/Fehler sichtbar.
- RPC nur public+aktive Cards; RLS owner-only-read; `coarse_geo` nur Land (optional, vorerst nicht vom Web gesetzt).
- iOS: load-Fehler → errorMessage, kein Crash.

## Tests gesamt
pgTAP 0005, vitest (connect + render), XCTest (store + VM); iOS+macOS Build grün; bestehende Suiten bleiben grün.

## Bewusst nicht hier
App-zu-App-Austausch; Geräte-Adressbuch-Export (CNContact); Push-Notification bei neuem Lead; Lead-Löschen/Tags/Notizen-Edit durch Owner; Web-`coarse_geo`-Befüllung.
