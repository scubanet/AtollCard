# Lead-Verbesserungen: Namens-Split, Adressbuch-Export, Löschen — Design

**Datum:** 2026-07-02
**Status:** freigegeben (Vorname + Nachname beide Pflicht)
**M2-Sub-Projekt 8.** Drei zusammenhängende Lead-Capture-Verbesserungen.

## Ziel
1. Web-„Verbinden"-Formular erfasst **Vorname + Nachname getrennt** (beide Pflicht).
2. Lead lässt sich aus dem Kontakte-Tab **ins System-Adressbuch übernehmen**.
3. Lead lässt sich **löschen** (swipe + Bestätigung).

## A. Backend — Migration `0011_connection_names_delete.sql` (lokal + Prod)
```sql
alter table public.connections
  add column first_name text,
  add column last_name text;

-- Owner darf Leads eigener Karten löschen
create policy "connections_delete_via_owner" on public.connections for delete
  using (exists (select 1 from public.cards c where c.id = connections.card_id and c.owner_id = auth.uid()));

-- RPC: neue optionale Params; name wird immer befüllt (Kompat mit altem Web/Anzeige)
create or replace function public.record_connection(
  p_slug text, p_name text default null, p_email text default null, p_phone text default null,
  p_company text default null, p_note text default null, p_coarse_geo text default null,
  p_first_name text default null, p_last_name text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_card_id uuid; v_name text;
begin
  v_name := nullif(trim(concat_ws(' ', p_first_name, p_last_name)), '');
  if v_name is null then v_name := nullif(trim(coalesce(p_name, '')), ''); end if;
  if v_name is null then return; end if;
  select id into v_card_id from public.cards
    where slug = p_slug and visibility = 'public' and is_active = true;
  if v_card_id is null then return; end if;
  insert into public.connections (card_id, name, first_name, last_name, email, phone, company, note, coarse_geo)
  values (v_card_id, v_name, nullif(trim(coalesce(p_first_name,'')),''), nullif(trim(coalesce(p_last_name,'')),''),
          p_email, p_phone, p_company, p_note, p_coarse_geo);
end; $$;
revoke execute on function public.record_connection(text,text,text,text,text,text,text,text,text) from public;
grant execute on function public.record_connection(text,text,text,text,text,text,text,text,text) to anon, authenticated;
```
Hinweis: `p_name` bekommt Default null → die **alte 7-Arg-Signatur wird ersetzt** (drop + create, PostgREST-named-args bleiben kompatibel: bereits deploytes Web ruft mit `p_name` → funktioniert weiter). Vorher `drop function public.record_connection(text,text,text,text,text,text,text);` (Signaturwechsel).
- pgTAP `0005` erweitert: record mit first/last → `name`='Vorname Nachname', Split-Felder gesetzt; Owner-DELETE löscht; Fremd-User-DELETE wirkungslos (0 rows).

## B. Web
- Formular: `c-firstname` „Vorname" (required) + `c-lastname` „Name" (required) statt `c-name`; autocomplete `given-name`/`family-name`.
- `ConnectPayload {firstName, lastName, email?, phone?, company?, note?}`; `validateConnect`: beide Namen nicht-leer; E-Mail-Check bleibt.
- `recordConnection` → `p_first_name`/`p_last_name` (kein `p_name` mehr vom neuen Web).
- vitest angepasst/erweitert. CI deployt automatisch.

## C. iOS
- `Connection` + `firstName: String?`, `lastName: String?` (CodingKeys `first_name`/`last_name`); computed `displayName: String` = „first last" (trimmed) fallback `name`. Anzeige in Liste/Detail via `displayName`.
- **Löschen:** `ConnectionStoring.delete(_ connectionId: UUID) async throws`; `SupabaseConnectionStore` → `.from("connections").delete().eq("id", …)` (RLS-DELETE-Policy); `InMemoryConnectionStore` mutable + delete. `ConnectionsViewModel.delete(_:)` (löscht + reload). ContactsView: swipe-to-delete + `confirmationDialog`.
- **Adressbuch:** `AtollCard/Features/Contacts/ContactExporting.swift`:
  - `protocol ContactExporting { func save(_ connection: Connection) async throws }`
  - Pure Mapping-Funktion `makeContact(from: Connection) -> CNMutableContact` (given=firstName/fallback erste Namenskomponente, family=lastName/Rest, email, phone, organizationName=company, note) — **unit-testbar**.
  - `SystemContactExporter`: `CNContactStore.requestAccess(for: .contacts)` → `CNSaveRequest` add. Fehler (verweigert) → aussagekräftige Meldung.
- `project.yml`: `INFOPLIST_KEY_NSContactsUsageDescription: "AtollCard speichert empfangene Kontakte auf Wunsch in dein Adressbuch."`
- `ConnectionDetailView`: Button **„In Kontakte sichern"** (Erfolg-Häkchen/Fehlertext); Übergabe des Exporters via Init (Default `SystemContactExporter()`), Fake für Preview/Test.
- Tests: `makeContact`-Mapping (Namen/Fallback-Split, Felder), VM-delete, InMemory-delete. Bestehende 49 grün.

## Verifikation
pgTAP lokal; Prod-Migration via MCP + Live-Check (record mit first/last, delete). Web-CI grün. iOS+macOS Build + Suite grün; iPad-Build. Interaktiv: Formular ausfüllen → Lead erscheint → „In Kontakte sichern" → im Adressbuch; swipe-löschen.

## Bewusst nicht hier
Editor für Leads; Duplikat-Erkennung im Adressbuch; Backfill von `first_name/last_name` für Alt-Leads (Anzeige-Fallback deckt ab).
