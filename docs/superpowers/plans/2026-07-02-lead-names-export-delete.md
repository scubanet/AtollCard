# Lead-Namens-Split, Adressbuch-Export, Löschen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web-Formular erfasst Vor-/Nachname getrennt (beide Pflicht); Leads lassen sich ins System-Adressbuch übernehmen und löschen.

**Architecture:** Migration 0011 (Split-Spalten + DELETE-Policy + erweiterte RPC, abwärtskompatibel via named-args). Web sendet `p_first_name`/`p_last_name`. iOS: `Connection` +Split-Felder, `ConnectionStoring.delete`, `ContactExporting`-Naht (CNContact) + UI.

**Tech Stack:** Postgres/pgTAP, Vite+TS+vitest, SwiftUI/Contacts-Framework/XCTest, XcodeGen.

**Konventionen:** Repo `~/Developer/AtollCard`. Backend: Implementer schreibt Dateien, Controller wendet lokal+Prod an. iOS: `xcodegen generate` nach Änderungen; Test-Dest `platform=iOS Simulator,name=iPhone 16e,OS=26.2`; macOS `platform=macOS,arch=arm64`. Web: `cd web && npm test`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `supabase/migrations/0011_connection_names_delete.sql` — Spalten, DELETE-Policy, RPC v2.
- `supabase/tests/0005_connections_test.sql` — erweitert.
- `web/src/render.ts`, `web/src/main.ts`, `web/src/lib/connect.ts`, `web/tests/connect.test.ts`, `web/tests/render.test.ts` — Formular-Split.
- `AtollCard/Models/Connection.swift` — Split-Felder + `displayName`.
- `AtollCard/Stores/ConnectionStoring.swift`, `InMemoryConnectionStore.swift`, `SupabaseConnectionStore.swift` — delete.
- `AtollCard/Features/Contacts/ContactExporting.swift` — Naht + Mapping + System-Exporter.
- `AtollCard/Features/Contacts/ConnectionsViewModel.swift`, `ContactsView.swift`, `ConnectionDetailView.swift` — delete-UI + Export-Button.
- `project.yml` — `INFOPLIST_KEY_NSContactsUsageDescription`.
- Tests: `AtollCardTests/ConnectionsViewModelTests.swift` (erweitert), `AtollCardTests/ContactExportTests.swift` (neu), `InMemoryConnectionStoreTests.swift` (erweitert).

---

## Task 1: Backend — Migration 0011 + pgTAP (nur Dateien)

**Files:** Create `supabase/migrations/0011_connection_names_delete.sql`; Modify `supabase/tests/0005_connections_test.sql`.

- [ ] **Step 1: Migration** — exakt der SQL-Block aus der Spec (`docs/superpowers/specs/2026-07-02-lead-names-export-delete-design.md`, Abschnitt A): erst `drop function public.record_connection(text,text,text,text,text,text,text);`, dann `alter table` (first_name/last_name), DELETE-Policy `connections_delete_via_owner`, neue 9-Arg-`record_connection` (v_name aus first/last, Fallback p_name, no-op wenn leer), revoke public + grant anon/authenticated auf die 9-Arg-Signatur.

- [ ] **Step 2: pgTAP erweitern** — in `supabase/tests/0005_connections_test.sql` `plan(4)`→`plan(7)` und vor `finish()` ergänzen:
```sql
-- split-name recording
set local role anon;
select lives_ok(
  $$select record_connection('jane-doe', p_first_name => 'Max', p_last_name => 'Muster')$$,
  'records with split names');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.connections where first_name='Max' and last_name='Muster' and name='Max Muster'),
  1, 'split names stored and combined into name');

-- owner can delete
select lives_ok($$delete from public.connections$$, 'owner delete does not error');
select is((select count(*)::int from public.connections), 0, 'owner deleted own leads');
```
(Reihenfolge beachten: die bestehenden Zählungs-Asserts laufen VOR den neuen Statements; neue Asserts ans Ende. Fremd-User-Delete ist durch die bestehende RLS-Struktur implizit — DELETE ohne Policy-Match löscht 0 Zeilen; der Owner-Fall genügt hier.)

- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/0011_connection_names_delete.sql supabase/tests/0005_connections_test.sql
git commit -m "feat(db): split lead names, owner delete policy, record_connection v2

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(Controller: lokal `supabase db reset && supabase test db`; Prod via MCP; TS-Typen regenerieren.)

---

## Task 2: Web-Formular-Split

**Files:** Modify `web/src/lib/connect.ts`, `web/src/render.ts`, `web/src/main.ts`, `web/tests/connect.test.ts`, `web/tests/render.test.ts`.

- [ ] **Step 1: Tests umschreiben** — `web/tests/connect.test.ts`: `ConnectPayload` nutzt jetzt `firstName`/`lastName`:
```ts
describe('validateConnect', () => {
  it('requires first and last name', () => {
    expect(validateConnect({ firstName: '', lastName: 'M' }).ok).toBe(false)
    expect(validateConnect({ firstName: 'Max', lastName: ' ' }).ok).toBe(false)
    expect(validateConnect({ firstName: 'Max', lastName: 'Muster' }).ok).toBe(true)
  })
  it('rejects a malformed email', () => {
    expect(validateConnect({ firstName: 'A', lastName: 'B', email: 'nope' }).ok).toBe(false)
  })
})

describe('recordConnection', () => {
  it('maps payload to the RPC params', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null })
    await recordConnection({ rpc }, 'jane-doe', { firstName: 'Max', lastName: 'Muster', email: 'm@x.co', phone: '1', company: 'Acme', note: 'hi' })
    expect(rpc).toHaveBeenCalledWith('record_connection', {
      p_slug: 'jane-doe', p_first_name: 'Max', p_last_name: 'Muster',
      p_email: 'm@x.co', p_phone: '1', p_company: 'Acme', p_note: 'hi',
    })
  })
  it('throws on rpc error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } })
    await expect(recordConnection({ rpc }, 's', { firstName: 'A', lastName: 'B' })).rejects.toThrow('boom')
  })
})
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: `connect.ts` umbauen**
```ts
export interface ConnectPayload {
  firstName: string
  lastName: string
  email?: string
  phone?: string
  company?: string
  note?: string
}

export function validateConnect(p: ConnectPayload): { ok: boolean; error?: string } {
  if (!p.firstName || p.firstName.trim() === '') return { ok: false, error: 'Vorname erforderlich' }
  if (!p.lastName || p.lastName.trim() === '') return { ok: false, error: 'Name erforderlich' }
  if (p.email && !/.+@.+\..+/.test(p.email)) return { ok: false, error: 'E-Mail ungültig' }
  return { ok: true }
}

export async function recordConnection(client: SupabaseLike, slug: string, p: ConnectPayload): Promise<void> {
  const { error } = await client.rpc('record_connection', {
    p_slug: slug,
    p_first_name: p.firstName,
    p_last_name: p.lastName,
    p_email: p.email ?? null,
    p_phone: p.phone ?? null,
    p_company: p.company ?? null,
    p_note: p.note ?? null,
  })
  if (error) throw new Error((error as { message?: string }).message ?? 'RPC error')
}
```

- [ ] **Step 4: Formular** — in `render.ts` das `c-name`-Feld ersetzen durch zwei Pflichtfelder (Labels + `required`, autocomplete `given-name`/`family-name`):
```html
<label class="connect-label" for="c-firstname">Vorname</label>
<input id="c-firstname" name="firstname" type="text" placeholder="Vorname" autocomplete="given-name" required />
<label class="connect-label" for="c-lastname">Name</label>
<input id="c-lastname" name="lastname" type="text" placeholder="Name" autocomplete="family-name" required />
```
`main.ts`: Feld-IDs lesen (`c-firstname`/`c-lastname`), Payload bauen. `render.test.ts`: Assertion auf `id="c-firstname"` + `id="c-lastname"` (statt `c-name`).

- [ ] **Step 5: `npm test` → alles grün.** Commit:
```bash
git add web/src/lib/connect.ts web/src/render.ts web/src/main.ts web/tests/connect.test.ts web/tests/render.test.ts
git commit -m "feat(web): split first/last name in connect form (both required)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(Push deployt via CI automatisch.)

---

## Task 3: iOS — Modell-Split, Löschen, Adressbuch-Export

**Files:** Modify `AtollCard/Models/Connection.swift`, `AtollCard/Stores/ConnectionStoring.swift`, `InMemoryConnectionStore.swift`, `SupabaseConnectionStore.swift`, `ConnectionsViewModel.swift`, `ContactsView.swift`, `ConnectionDetailView.swift`, `project.yml`; Create `AtollCard/Features/Contacts/ContactExporting.swift`; Tests: `ContactExportTests.swift` (neu), `ConnectionsViewModelTests.swift` + `InMemoryConnectionStoreTests.swift` (erweitert).

- [ ] **Step 1: Failing tests**
`AtollCardTests/ContactExportTests.swift` (neu):
```swift
import XCTest
import Contacts
@testable import AtollCard

final class ContactExportTests: XCTestCase {
    func test_mapsSplitNamesAndFields() {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Max Muster",
            firstName: "Max", lastName: "Muster", email: "m@x.co", phone: "+41 79",
            company: "Acme", note: "Messe", createdAt: Date())
        let contact = ContactMapper.makeContact(from: c)
        XCTAssertEqual(contact.givenName, "Max")
        XCTAssertEqual(contact.familyName, "Muster")
        XCTAssertEqual(contact.emailAddresses.first?.value as String?, "m@x.co")
        XCTAssertEqual(contact.phoneNumbers.first?.value.stringValue, "+41 79")
        XCTAssertEqual(contact.organizationName, "Acme")
        XCTAssertEqual(contact.note, "Messe")
    }
    func test_fallbackSplitsLegacyName() {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Erika Beispiel Frau",
            firstName: nil, lastName: nil, email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date())
        let contact = ContactMapper.makeContact(from: c)
        XCTAssertEqual(contact.givenName, "Erika")
        XCTAssertEqual(contact.familyName, "Beispiel Frau")
    }
}
```
`ConnectionsViewModelTests.swift` ergänzen:
```swift
    func test_deleteRemovesConnection() async {
        let c = Connection(id: UUID(), cardId: UUID(), name: "X", firstName: nil, lastName: nil,
            email: nil, phone: nil, company: nil, note: nil, createdAt: Date())
        let store = InMemoryConnectionStore(seed: [c])
        let vm = ConnectionsViewModel(store: store, ownerId: UUID())
        await vm.load()
        await vm.delete(c.id)
        XCTAssertTrue(vm.connections.isEmpty)
    }
```
`InMemoryConnectionStoreTests` bestehende Inits um `firstName: nil, lastName: nil` erweitern (Compile), plus:
```swift
    func test_deleteRemovesFromSeed() async throws {
        let c = Connection(id: UUID(), cardId: UUID(), name: "A", firstName: nil, lastName: nil,
            email: nil, phone: nil, company: nil, note: nil, createdAt: Date())
        let store = InMemoryConnectionStore(seed: [c])
        try await store.delete(c.id)
        let rest = try await store.connections(forOwner: UUID())
        XCTAssertTrue(rest.isEmpty)
    }
```

- [ ] **Step 2: Run → FAIL** (firstName/ContactMapper/delete fehlen).

- [ ] **Step 3: Modell** — `Connection.swift`: `var firstName: String?`, `var lastName: String?` nach `name`; CodingKeys `firstName = "first_name"`, `lastName = "last_name"`; computed:
```swift
    var displayName: String {
        let combined = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? name : combined
    }
```

- [ ] **Step 4: Stores** — `ConnectionStoring` + `func delete(_ connectionId: UUID) async throws`. `InMemoryConnectionStore`: `private var seed` → mutable, `delete` entfernt per id. `SupabaseConnectionStore`:
```swift
    func delete(_ connectionId: UUID) async throws {
        try await client.from("connections").delete()
            .eq("id", value: connectionId.uuidString).execute()
    }
```

- [ ] **Step 5: ContactExporting** — `AtollCard/Features/Contacts/ContactExporting.swift`:
```swift
import Foundation
import Contacts

protocol ContactExporting {
    func save(_ connection: Connection) async throws
}

enum ContactMapper {
    static func makeContact(from c: Connection) -> CNMutableContact {
        let contact = CNMutableContact()
        if let first = c.firstName, !first.isEmpty {
            contact.givenName = first
            contact.familyName = c.lastName ?? ""
        } else {
            let parts = c.name.split(separator: " ", maxSplits: 1).map(String.init)
            contact.givenName = parts.first ?? c.name
            contact.familyName = parts.count > 1 ? parts[1] : ""
        }
        if let email = c.email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = c.phone, !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                   value: CNPhoneNumber(stringValue: phone))]
        }
        if let company = c.company { contact.organizationName = company }
        if let note = c.note { contact.note = note }
        return contact
    }
}

struct SystemContactExporter: ContactExporting {
    func save(_ connection: Connection) async throws {
        let store = CNContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        guard granted else {
            throw NSError(domain: "AtollCard", code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Zugriff auf Kontakte nicht erlaubt. In den Einstellungen freigeben."])
        }
        let request = CNSaveRequest()
        request.add(ContactMapper.makeContact(from: connection), toContainerWithIdentifier: nil)
        try store.execute(request)
    }
}
```
HINWEIS: `contact.note` setzen kann ohne com.apple.developer.contacts.notes-Entitlement beim SAVE ok sein (nur Lesen ist geschützt); falls der Save auf Gerät scheitert, note weglassen und melden.

- [ ] **Step 6: VM + UI**
- `ConnectionsViewModel` + `func delete(_ id: UUID) async { do { try await store.delete(id); connections = try await store.connections(forOwner: ownerId) } catch { errorMessage = error.localizedDescription } }`
- `ContactsView`: Liste → swipe-to-delete (`.swipeActions` Button destruktiv) + `confirmationDialog` („Kontakt löschen?") → `await vm.delete(id)`. Anzeige `c.displayName` statt `c.name`.
- `ConnectionDetailView`: `let exporter: ContactExporting = SystemContactExporter()` (Init-Param mit Default); Titel `connection.displayName`; Button **„In Kontakte sichern"** (icon `person.crop.circle.badge.plus`): `@State saved/exportError`; bei Erfolg Häkchen+„Gesichert", Fehler → roter Text. Glas-Stil.
- `project.yml` → app-Target `settings.base`: `INFOPLIST_KEY_NSContactsUsageDescription: "AtollCard speichert empfangene Kontakte auf Wunsch in dein Adressbuch."`

- [ ] **Step 7: Run** — `xcodegen generate`; volle iOS-Suite (49 + 4 neu = 53) grün; macOS-Build grün.

- [ ] **Step 8: Commit**
```bash
git add AtollCard AtollCardTests project.yml
git commit -m "feat(ios): lead split names, save-to-contacts, swipe delete

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Gate (Controller)
- [ ] Lokal: `supabase db reset && supabase test db` (0005 = 7 Asserts grün).
- [ ] Prod: 0011 via MCP (`drop function` + apply); Live-Check: RPC mit first/last → Lead mit kombinierten name; anon delete → 0 rows; TS-Typen regenerieren + committen.
- [ ] Web: push → CI grün → Live-Formular zeigt Vorname/Name.
- [ ] iOS: iPad-Build + Install. Interaktiv (Nutzer): Formular → Lead → „In Kontakte sichern" → Adressbuch; swipe-löschen.

---

## Self-Review
- **Spec-Abdeckung:** Migration+Policy+RPC v2+pgTAP (T1), Web-Split beide Pflicht (T2), iOS Modell/delete/Exporter/UI/Permission (T3), Apply+Deploy+E2E (T4). ✓
- **Platzhalter:** keine — SQL in Spec referenziert (ein Dokument, exakt), restlicher Code inline. ✓
- **Typkonsistenz:** RPC-Param-Namen `p_first_name`/`p_last_name` in SQL (Spec A) = Web (T2) = pgTAP (T1). `Connection(firstName:lastName:)`-Init-Reihenfolge in allen Tests identisch (nach `name`). `ConnectionStoring.delete(_:)` Protokoll=InMemory=Supabase=VM. `ContactMapper.makeContact(from:)` Def (T3 S5) = Tests (T3 S1). ✓
- **Risiko:** `CNContactStore.requestAccess` async-throws-Variante; falls SDK-Signatur (callback) → mit `withCheckedThrowingContinuation` wrappen. `note`-Save ggf. entitlement-pflichtig → Fallback dokumentiert.
