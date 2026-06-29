# Kontakte-Empfang (Lead-Capture) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Besucher hinterlässt Kontaktdaten auf dem Web-Profil → als `connection` beim Karten-Owner gespeichert → iOS-Kontakte-Tab listet Leads (Liste + Detail).

**Architecture:** Anonyme `record_connection`-RPC (`SECURITY DEFINER`, public Cards) schreibt in `connections` (RLS: owner-only-read). Web rendert ein „Verbinden"-Formular mit Consent-Checkbox. iOS liest via `ConnectionStoring`-Naht (RLS-gefiltert).

**Tech Stack:** Supabase/Postgres/pgTAP, Vite+TS+vitest (Web), SwiftUI+XCTest (iOS), XcodeGen, supabase-swift 2.48.

**Konventionen:** Repo `~/Developer/AtollCard`. iOS: nach neuen Dateien `xcodegen generate`; Test `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' [-only-testing:...]`; macOS `-destination 'platform=macOS,arch=arm64'`. Web: `cd web && npm test`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **Backend (Task 1): Implementer schreibt nur Dateien; Controller wendet auf lokal+Prod an und verifiziert.**

---

## File Structure
- `supabase/migrations/0010_connections.sql` — Tabelle + RLS + `record_connection`-RPC.
- `supabase/tests/0005_connections_test.sql` — pgTAP.
- `web/src/lib/connect.ts` — `recordConnection` + Validierung.
- `web/tests/connect.test.ts` — vitest.
- `web/src/render.ts`, `web/src/main.ts` — „Verbinden"-Formular + Wiring.
- `AtollCard/Models/Connection.swift` — Model + Date-Strategie.
- `AtollCard/Stores/ConnectionStoring.swift`, `InMemoryConnectionStore.swift`, `SupabaseConnectionStore.swift`.
- `AtollCard/Features/Contacts/ConnectionsViewModel.swift`, `ContactsView.swift` (ersetzt Placeholder), `ConnectionDetailView.swift`.
- `AtollCard/Stores/AppStores.swift` — `connectionStore`-DI.
- Tests: `AtollCardTests/InMemoryConnectionStoreTests.swift`, `ConnectionsViewModelTests.swift`.

---

## Task 1: Backend `connections` + `record_connection` (Dateien)

**Files:** Create `supabase/migrations/0010_connections.sql`, `supabase/tests/0005_connections_test.sql`.

- [ ] **Step 1: Migration** `supabase/migrations/0010_connections.sql`
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
create policy "connections_select_via_owner" on public.connections for select
  using (exists (select 1 from public.cards c where c.id = connections.card_id and c.owner_id = auth.uid()));

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

- [ ] **Step 2: pgTAP** `supabase/tests/0005_connections_test.sql`
```sql
begin;
select plan(4);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'owner@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'other@example.com');

insert into public.cards (id, owner_id, slug, display_name, visibility)
values
  ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','jane-doe','Jane Doe','public'),
  ('cccccccc-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','secret','Secret','private');

set local role anon;
select lives_ok(
  $$select record_connection('jane-doe','Max Muster','max@x.com','123','Acme','Hi')$$,
  'anon records a connection for a public card');
select lives_ok(
  $$select record_connection('secret','Nope')$$,
  'recording against private card is a no-op (no error)');

-- owner sees exactly the one lead
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from public.connections), 1, 'owner sees only the public-card lead');

-- other user sees none
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.connections), 0, 'foreign user sees no leads (RLS)');

select * from finish();
rollback;
```

- [ ] **Step 3: Build-Sanity (kein DB-Zugriff für den Implementer)** — nur sicherstellen, dass die Dateien syntaktisch sauber sind (Review). Nicht ausführen.

- [ ] **Step 4: Commit**
```bash
git add supabase/migrations/0010_connections.sql supabase/tests/0005_connections_test.sql
git commit -m "feat(db): connections table + record_connection RPC (lead capture)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(Controller wendet auf lokal+Prod an, fährt `supabase test db` bzw. live-Checks.)

---

## Task 2: Web `recordConnection` + Formular

**Files:** Create `web/src/lib/connect.ts`, `web/tests/connect.test.ts`; Modify `web/src/render.ts`, `web/src/main.ts`.

- [ ] **Step 1: Failing test** `web/tests/connect.test.ts`
```ts
import { describe, it, expect, vi } from 'vitest'
import { recordConnection, validateConnect } from '../src/lib/connect'

describe('validateConnect', () => {
  it('requires a name', () => {
    expect(validateConnect({ name: '' }).ok).toBe(false)
    expect(validateConnect({ name: '  ' }).ok).toBe(false)
  })
  it('rejects a malformed email', () => {
    expect(validateConnect({ name: 'A', email: 'nope' }).ok).toBe(false)
  })
  it('accepts name only and name+valid email', () => {
    expect(validateConnect({ name: 'A' }).ok).toBe(true)
    expect(validateConnect({ name: 'A', email: 'a@b.co' }).ok).toBe(true)
  })
})

describe('recordConnection', () => {
  it('maps payload to the RPC params', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null })
    await recordConnection({ rpc }, 'jane-doe', { name: 'Max', email: 'm@x.co', phone: '1', company: 'Acme', note: 'hi' })
    expect(rpc).toHaveBeenCalledWith('record_connection', {
      p_slug: 'jane-doe', p_name: 'Max', p_email: 'm@x.co', p_phone: '1', p_company: 'Acme', p_note: 'hi',
    })
  })
  it('throws on rpc error', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'boom' } })
    await expect(recordConnection({ rpc }, 's', { name: 'A' })).rejects.toThrow('boom')
  })
})
```

- [ ] **Step 2: Run → FAIL.** `cd web && npx vitest run connect` → modul fehlt.

- [ ] **Step 3: Implement** `web/src/lib/connect.ts`
```ts
import type { SupabaseLike } from './api'

export interface ConnectPayload {
  name: string
  email?: string
  phone?: string
  company?: string
  note?: string
}

export function validateConnect(p: ConnectPayload): { ok: boolean; error?: string } {
  if (!p.name || p.name.trim() === '') return { ok: false, error: 'Name erforderlich' }
  if (p.email && !/.+@.+\..+/.test(p.email)) return { ok: false, error: 'E-Mail ungültig' }
  return { ok: true }
}

export async function recordConnection(client: SupabaseLike, slug: string, p: ConnectPayload): Promise<void> {
  const { error } = await client.rpc('record_connection', {
    p_slug: slug,
    p_name: p.name,
    p_email: p.email ?? null,
    p_phone: p.phone ?? null,
    p_company: p.company ?? null,
    p_note: p.note ?? null,
  })
  if (error) throw new Error((error as { message?: string }).message ?? 'RPC error')
}
```

- [ ] **Step 4: Run → PASS.** `cd web && npx vitest run connect`.

- [ ] **Step 5: Formular im Renderer.** In `web/src/render.ts` nach dem `save-contact`-Button einen „Verbinden"-Block einfügen (HTML-Escaping-Konventionen des Files beachten):
```html
<button id="connect-toggle" type="button">Verbinden</button>
<form id="connect-form" hidden>
  <input id="c-name" type="text" placeholder="Name" required />
  <input id="c-email" type="email" placeholder="E-Mail" />
  <input id="c-phone" type="tel" placeholder="Telefon" />
  <input id="c-company" type="text" placeholder="Firma" />
  <textarea id="c-note" placeholder="Nachricht"></textarea>
  <label><input id="c-consent" type="checkbox" /> Ich willige ein, dass meine Daten an den Karteninhaber übermittelt werden.</label>
  <button id="c-submit" type="submit">Senden</button>
  <p id="c-status"></p>
</form>
```
In `web/src/main.ts` verdrahten: `connect-toggle` toggelt `hidden`; submit-Handler `preventDefault`, liest Felder, prüft Consent-Checkbox + `validateConnect`, ruft `recordConnection(client, slug, payload)`, setzt `#c-status` auf Erfolg/Fehler, leert/versteckt das Formular bei Erfolg. Pattern wie der bestehende `save-contact`-Listener.

- [ ] **Step 6: Render-Test** in `web/tests/render.test.ts` ergänzen (oder neuer Test): nach `renderCard(...)` enthält das Markup `id="connect-form"` und ein `required` Name-Feld. Run `cd web && npm test` → alles grün (inkl. bestehende 23+).

- [ ] **Step 7: Commit**
```bash
git add web/src/lib/connect.ts web/tests/connect.test.ts web/src/render.ts web/src/main.ts web/tests/render.test.ts
git commit -m "feat(web): connect form + recordConnection (lead capture)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: iOS Model + Stores + ViewModel + DI

**Files:** Create `AtollCard/Models/Connection.swift`, `AtollCard/Stores/ConnectionStoring.swift`, `InMemoryConnectionStore.swift`, `SupabaseConnectionStore.swift`, `AtollCard/Features/Contacts/ConnectionsViewModel.swift`; Modify `AtollCard/Stores/AppStores.swift`, `AtollCard/Models/Card.swift` (Decoder-Date-Strategie); Test `AtollCardTests/InMemoryConnectionStoreTests.swift`, `ConnectionsViewModelTests.swift`.

- [ ] **Step 1: Failing tests**
`AtollCardTests/InMemoryConnectionStoreTests.swift`:
```swift
import XCTest
@testable import AtollCard

final class InMemoryConnectionStoreTests: XCTestCase {
    func test_listsSeededConnectionsNewestFirst() async throws {
        let owner = UUID()
        let older = Connection(id: UUID(), cardId: UUID(), name: "A", email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date(timeIntervalSince1970: 100))
        let newer = Connection(id: UUID(), cardId: UUID(), name: "B", email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date(timeIntervalSince1970: 200))
        let store = InMemoryConnectionStore(seed: [older, newer])
        let list = try await store.connections(forOwner: owner)
        XCTAssertEqual(list.map(\.name), ["B", "A"])
    }
}
```
`AtollCardTests/ConnectionsViewModelTests.swift`:
```swift
import XCTest
@testable import AtollCard

@MainActor
final class ConnectionsViewModelTests: XCTestCase {
    func test_loadPopulates() async {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Max", email: "m@x.co", phone: nil,
            company: "Acme", note: nil, createdAt: Date())
        let vm = ConnectionsViewModel(store: InMemoryConnectionStore(seed: [c]), ownerId: UUID())
        await vm.load()
        XCTAssertEqual(vm.connections.count, 1)
        XCTAssertNil(vm.errorMessage)
    }
}
```

- [ ] **Step 2: Run → FAIL** (Typen fehlen).

- [ ] **Step 3: Model** `AtollCard/Models/Connection.swift`
```swift
import Foundation

struct Connection: Codable, Identifiable, Equatable {
    var id: UUID
    var cardId: UUID
    var name: String
    var email: String?
    var phone: String?
    var company: String?
    var note: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, company, note
        case cardId = "card_id"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 4: Decoder-Date-Strategie** — in `AtollCard/Models/Card.swift` `JSONDecoder.atoll` ersetzen durch (robust für PostgREST-Timestamps mit/ohne Sekundenbruchteile):
```swift
extension JSONDecoder {
    static let atoll: JSONDecoder = {
        let d = JSONDecoder()
        let withFrac = ISO8601DateFormatter(); withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter(); plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = withFrac.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Unrecognized date: \(s)"))
        }
        return d
    }()
}
```
(Bestehende Modelle haben keine `Date`-Felder → unverändertes Verhalten für sie.)

- [ ] **Step 5: Naht + Fakes**
`AtollCard/Stores/ConnectionStoring.swift`:
```swift
import Foundation
protocol ConnectionStoring {
    func connections(forOwner ownerId: UUID) async throws -> [Connection]
}
```
`AtollCard/Stores/InMemoryConnectionStore.swift`:
```swift
import Foundation
final class InMemoryConnectionStore: ConnectionStoring {
    private let seed: [Connection]
    init(seed: [Connection] = []) { self.seed = seed }
    func connections(forOwner ownerId: UUID) async throws -> [Connection] {
        seed.sorted { $0.createdAt > $1.createdAt }
    }
}
```
`AtollCard/Stores/SupabaseConnectionStore.swift`:
```swift
import Foundation
import Supabase
final class SupabaseConnectionStore: ConnectionStoring {
    private let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }
    func connections(forOwner ownerId: UUID) async throws -> [Connection] {
        try await client.from("connections")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value   // RLS returns only the caller's leads
    }
}
```

- [ ] **Step 6: ViewModel** `AtollCard/Features/Contacts/ConnectionsViewModel.swift`
```swift
import Foundation

@MainActor
final class ConnectionsViewModel: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var errorMessage: String?

    private let store: ConnectionStoring
    private let ownerId: UUID

    init(store: ConnectionStoring, ownerId: UUID) {
        self.store = store
        self.ownerId = ownerId
    }

    func load() async {
        do {
            connections = try await store.connections(forOwner: ownerId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 7: AppStores + DI** — Feld `let connectionStore: ConnectionStoring`; `.default` → `SupabaseConnectionStore()`, `.preview` → `InMemoryConnectionStore()`.

- [ ] **Step 8: Run → PASS** (beide neue Tests). Dann iOS-Test-Suite + macOS-Build grün.

- [ ] **Step 9: Commit**
```bash
git add AtollCard/Models/Connection.swift AtollCard/Models/Card.swift AtollCard/Stores/ConnectionStoring.swift AtollCard/Stores/InMemoryConnectionStore.swift AtollCard/Stores/SupabaseConnectionStore.swift AtollCard/Features/Contacts/ConnectionsViewModel.swift AtollCard/Stores/AppStores.swift AtollCardTests/InMemoryConnectionStoreTests.swift AtollCardTests/ConnectionsViewModelTests.swift
git commit -m "feat(ios): connection model, store seam, view model (lead capture)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: iOS Kontakte-Tab UI

**Files:** Modify `AtollCard/Features/Contacts/ContactsView.swift`; Create `AtollCard/Features/Contacts/ConnectionDetailView.swift`; Modify `AtollCard/Features/Shell/RootTabView.swift`, `AtollCard/App/AtollCardApp.swift` (connectionStore + ownerId durchreichen).

- [ ] **Step 1: ContactsView umbauen.** Signatur `ContactsView(store: ConnectionStoring, ownerId: UUID)`; `@StateObject private var vm`; `init` baut `ConnectionsViewModel(store:ownerId:)`. `.task { await vm.load() }`. Bei leerer Liste: bestehender „Bald verfügbar"/Empty-Glas-Block (Text anpassen zu „Noch keine Kontakte – geteilte Karten sammeln Leads hier."). Bei Inhalt: `List`/`ForEach(vm.connections)` in Glas-Karten — Name (`Font.atoll(17,bold)`), Firma (`text2`), relatives Datum (`createdAt`, `.formatted(.relative(presentation:.named))`). Jede Zeile `NavigationLink(value:)` oder `NavigationLink { ConnectionDetailView(connection:) }`. Header „Kontakte"/„Dein Netzwerk" bleibt. `errorMessage` als roter Text falls gesetzt.

- [ ] **Step 2: ConnectionDetailView** `AtollCard/Features/Contacts/ConnectionDetailView.swift`: zeigt `name` (groß), `company`, `note`; Zeilen für `email` und `phone` nur wenn vorhanden. E-Mail → `Link(destination: URL(string: "mailto:\(email)")!)`. Telefon → unter `#if os(iOS)` `Link(destination: URL(string: "tel:\(phone)")!)`, sonst nur Text. Glas-Stil + `Theme`/`Font.atoll`. Dekorative Icons `accessibilityHidden(true)`; Mail/Tel-Links mit klarem Label.

- [ ] **Step 3: Wiring.** In `RootTabView` `connectionStore: ConnectionStoring` als Property + Init-Param ergänzen; `ContactsView(store: connectionStore, ownerId: ownerId)` statt Placeholder. In `AtollCardApp` `connectionStore: stores.connectionStore` an `RootTabView` durchreichen. `grep -rn "ContactsView(" AtollCard` und `RootTabView(` anpassen (inkl. Previews → `AppStores.preview.connectionStore`).

- [ ] **Step 4: Build + Tests beide Plattformen**
```
xcodegen generate
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: TEST SUCCEEDED, beide BUILD SUCCEEDED.

- [ ] **Step 5: Commit**
```bash
git add AtollCard/Features/Contacts AtollCard/Features/Shell/RootTabView.swift AtollCard/App/AtollCardApp.swift
git commit -m "feat(ios): contacts tab — leads list + detail (tap-to-call/mail)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Verifikationsgate

**Files:** keine.

- [ ] **Step 1: Web + iOS Suiten + Builds grün** (`cd web && npm test`; `xcodegen generate`; iOS test; macOS build).
- [ ] **Step 2: Controller wendet `0010` auf lokal (`supabase db reset && supabase test db` → 0005 grün) + Prod (MCP) an.**
- [ ] **Step 3: Controller live-Check Prod:** anon `record_connection('<public-slug>','Test Lead','t@x.co',...)` → 204; als Owner via RLS sichtbar; private/leerer Name → kein Insert; anon `select connections` → `[]` (RLS).

---

## Self-Review
- **Spec-Abdeckung:** connections+RPC+pgTAP (T1), Web connect+Formular+Consent (T2), iOS Model/Naht/VM/DI+Date-Strategie (T3), Kontakte-Tab Liste+Detail+tap-to-call/mail+Wiring (T4), Backend-Apply+Live-Check (T5). ✓
- **Platzhalter:** keine; voller Code für SQL, pgTAP, connect.ts, Tests, Model/Stores/VM; UI mit konkreten APIs (bestehende Views, Implementer passt an). ✓
- **Typkonsistenz:** `record_connection(p_slug,p_name,p_email,p_phone,p_company,p_note,p_coarse_geo)` identisch in SQL (T1), web (T2, ohne p_coarse_geo → default null) und Live-Check (T5). `ConnectionStoring.connections(forOwner:)` in Protokoll/Fakes/Supabase/VM (T3) + UI (T4). `Connection`-Felder + CodingKeys (T3) ↔ Tabellen-Spalten (T1). `ConnectPayload` (T2) = Formularfelder. ✓
- **Hinweis:** `recordConnection` (Web) sendet kein `p_coarse_geo` → RPC-Default `null`; konsistent mit Spec (Web setzt coarse_geo vorerst nicht).
