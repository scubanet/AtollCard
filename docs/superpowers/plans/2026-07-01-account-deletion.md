# Konto löschen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In-App-Kontolöschung (App-Store-Pflicht 5.1.1(v)): Edge Function löscht Storage + auth-User (DB cascadet); Settings-Zeile mit zweistufiger Bestätigung.

**Architecture:** `delete-account`-Edge-Function liest die User-ID aus dem Caller-JWT und löscht mit Service-Role Storage-Objekte + `auth.admin.deleteUser` (FK-Cascade räumt alle Tabellen). iOS erweitert die `Authenticating`-Naht um `deleteAccount()`; `AuthViewModel` behandelt Erfolg wie Sign-out.

**Tech Stack:** Deno (`npm:@supabase/supabase-js`), SwiftUI, XCTest, XcodeGen.

**Konventionen:** Repo `~/Developer/AtollCard`. Edge-Deploy macht der Controller (MCP). iOS: nach Änderungen `xcodegen generate`; Test `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`; macOS `-destination 'platform=macOS,arch=arm64'`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Edge Function `delete-account`

**Files:** Create `supabase/functions/delete-account/index.ts`.

- [ ] **Step 1: Implement** `supabase/functions/delete-account/index.ts`
```ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...cors, "content-type": "application/json" } });
  try {
    // 1) Identify the caller from their JWT (never from parameters).
    const authed = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );
    const { data: userData, error: userErr } = await authed.auth.getUser();
    if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
    const uid = userData.user.id;

    // 2) Service-role client for storage cleanup + user deletion.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 2a) Remove all card-media under <uid>/ (list card folders, then files).
    const bucket = admin.storage.from("card-media");
    const { data: cardDirs } = await bucket.list(uid, { limit: 1000 });
    const paths: string[] = [];
    for (const entry of cardDirs ?? []) {
      if (entry.id === null) {
        // folder → list its files
        const { data: files } = await bucket.list(`${uid}/${entry.name}`, { limit: 1000 });
        for (const f of files ?? []) paths.push(`${uid}/${entry.name}/${f.name}`);
      } else {
        paths.push(`${uid}/${entry.name}`);
      }
    }
    if (paths.length > 0) await bucket.remove(paths);

    // 2b) Delete the auth user — FK cascade removes profiles/cards/fields/events/connections.
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) return json({ error: delErr.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
```

- [ ] **Step 2: Sanity** — `deno check index.ts` (Typed-Array/BodyInit-Kosmetik wäre ok; hier keine Binärantwort → erwarte sauber). Kein Deploy (Controller).

- [ ] **Step 3: Commit**
```bash
git add supabase/functions/delete-account
git commit -m "feat(edge): delete-account — storage cleanup + auth user deletion (cascade)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: iOS deleteAccount + Settings-UI

**Files:** Modify `AtollCard/Features/Auth/AuthViewModel.swift`, `AtollCard/Stores/SupabaseAuthenticator.swift`, `AtollCard/Stores/AppStores.swift`, `AtollCard/Features/Settings/SettingsView.swift`; Test `AtollCardTests/AuthViewModelTests.swift`.

- [ ] **Step 1: Failing tests** — in `AtollCardTests/AuthViewModelTests.swift` den `FakeAuthenticator` erweitern:
```swift
    var deleteResult: Result<Void, Error> = .success(())
    func deleteAccount() async throws { try deleteResult.get() }
```
Neue Tests:
```swift
    func test_deleteAccountSignsOutOnSuccess() async {
        let id = UUID()
        let vm = AuthViewModel(authenticator: FakeAuthenticator(currentUserIdResult: id))
        await vm.restore()
        XCTAssertEqual(vm.userId, id)
        await vm.deleteAccount()
        XCTAssertNil(vm.userId)
        XCTAssertNil(vm.errorMessage)
    }
    func test_deleteAccountFailureKeepsSessionAndSetsError() async {
        let id = UUID()
        var fake = FakeAuthenticator(currentUserIdResult: id)
        fake.deleteResult = .failure(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        let vm = AuthViewModel(authenticator: fake)
        await vm.restore()
        await vm.deleteAccount()
        XCTAssertEqual(vm.userId, id)
        XCTAssertEqual(vm.errorMessage, "boom")
    }
```

- [ ] **Step 2: Run → FAIL** (`deleteAccount` fehlt im Protokoll).

- [ ] **Step 3: Naht + VM**
- `Authenticating`-Protokoll (in `AuthViewModel.swift`): `func deleteAccount() async throws` ergänzen.
- `AuthViewModel`:
```swift
    func deleteAccount() async {
        do {
            try await authenticator.deleteAccount()
            userId = nil
            errorMessage = nil
            AtollAppGroup.save(nil)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```
- `SupabaseAuthenticator`:
```swift
    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        try? await client.auth.signOut()
    }
```
(Void-`invoke`-Variante; wirft bei non-2xx. Falls die Signatur options braucht: `invoke("delete-account", options: FunctionInvokeOptions())`.)
- `PreviewAuthenticator` (AppStores.swift): `func deleteAccount() async throws {}`.

- [ ] **Step 4: Settings-UI** — in `SettingsView` „Konto"-Sektion nach „Abmelden" eine destruktive Zeile:
```swift
                    SettingsRow(icon: "trash", title: "Konto löschen", subtitle: nil, isDestructive: true) {
                        showDeleteStep1 = true
                    }
```
State + zweistufige Bestätigung an der View:
```swift
    @State private var showDeleteStep1 = false
    @State private var showDeleteStep2 = false
    @State private var isDeleting = false
    // Modifier:
    .confirmationDialog("Konto löschen?", isPresented: $showDeleteStep1, titleVisibility: .visible) {
        Button("Weiter", role: .destructive) { showDeleteStep2 = true }
        Button("Abbrechen", role: .cancel) {}
    } message: { Text("Dein Konto und alle Daten werden gelöscht.") }
    .alert("Wirklich löschen?", isPresented: $showDeleteStep2) {
        Button("Endgültig löschen", role: .destructive) {
            isDeleting = true
            Task { await authVM.deleteAccount(); isDeleting = false }
        }
        Button("Abbrechen", role: .cancel) {}
    } message: { Text("Alle Karten, Kontakte und Bilder werden unwiderruflich gelöscht.") }
```
`isDeleting` → `ProgressView`/disabled auf der Zeile. `authVM.errorMessage` sichtbar machen (kleiner roter Text in der Konto-Sektion), falls Löschung fehlschlägt.

- [ ] **Step 5: Run → PASS** (49: 47 + 2). macOS-Build grün.

- [ ] **Step 6: Commit**
```bash
git add AtollCard/Features/Auth/AuthViewModel.swift AtollCard/Stores/SupabaseAuthenticator.swift AtollCard/Stores/AppStores.swift AtollCard/Features/Settings/SettingsView.swift AtollCardTests/AuthViewModelTests.swift
git commit -m "feat(ios): in-app account deletion (two-step confirm, App Store 5.1.1v)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Deploy + Gate (Controller)
- [ ] Deploy `delete-account` via MCP (`verify_jwt: true`); unauth → 401.
- [ ] Cascade-E2E lokal: `supabase start`; User+Karte(+Field) via REST anlegen; Löschlogik mit lokalem Service-Role-Key nachstellen (Storage-remove + `auth.admin.deleteUser`); prüfen: users/cards/connections leer.
- [ ] Interaktiv (Nutzer): Settings → Konto löschen auf iPad → SignInView; neuer Apple-Login = frisches Konto.

---

## Self-Review
- **Spec-Abdeckung:** Edge (JWT-Identität, Storage-Cleanup, admin.deleteUser) T1; Naht+VM+zweistufige UI T2; Deploy+E2E T3. ✓
- **Platzhalter:** keine. ✓
- **Typkonsistenz:** `Authenticating.deleteAccount()` in Protokoll/Fake/Supabase/Preview identisch; `FakeAuthenticator` behält memberwise-Init (neue Props mit Default). Secret-Namen: `SUPABASE_SERVICE_ROLE_KEY` (auto-injiziert), kein neues Secret nötig. ✓
