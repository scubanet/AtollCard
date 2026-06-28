# Sign in with Apple Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ersetze den E-Mail/Passwort-Login der AtollCard iOS/macOS-App durch nativen „Sign in with Apple" (Supabase `signInWithIdToken`).

**Architecture:** `AuthenticationServices`-`SignInWithAppleButton` in der View erzeugt einen Nonce (zufällig + SHA256) und liefert `(idToken, rawNonce)` an `AuthViewModel`. Die `Authenticating`-Naht ruft `SupabaseAuthenticator.signInWithIdToken(.apple)`. Reine Logik (Nonce, VM) ist unit-getestet; der ASAuthorization-Dialog lebt dünn in der View.

**Tech Stack:** SwiftUI, AuthenticationServices, CryptoKit, supabase-swift 2.48, XCTest. XcodeGen (`project.yml`). Swift 5 Sprachmodus.

**Konventionen (jede Task):** Repo `~/Developer/AtollCard`. Nach neuen Dateien `xcodegen generate`. Test: `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' [-only-testing:...]`. macOS-Build: `-destination 'platform=macOS,arch=arm64'`. Commit-Messages enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `AtollCard/Features/Auth/NonceGenerator.swift` — Zufalls-Nonce + SHA256-Hex (CryptoKit). Rein, testbar.
- `AtollCard/Features/Auth/AuthViewModel.swift` — `Authenticating`-Protokoll + VM, umgestellt auf `signIn(idToken:nonce:)`.
- `AtollCard/Stores/SupabaseAuthenticator.swift` — `signInWithIdToken(.apple)`.
- `AtollCard/Stores/AppStores.swift` — `PreviewAuthenticator` an neues Protokoll anpassen.
- `AtollCard/Features/Auth/SignInView.swift` — `SignInWithAppleButton` + Apple-Flow.
- `AtollCard/Features/Auth/ProfileNameUpdater.swift` — schreibt `profiles.display_name` nach Erst-Login.
- `AtollCard/AtollCard.entitlements` — `com.apple.developer.applesignin`.
- `project.yml` — `CODE_SIGN_ENTITLEMENTS` (iOS+macOS).
- Tests: `AtollCardTests/NonceGeneratorTests.swift`, `AtollCardTests/AuthViewModelTests.swift` (umgebaut).

---

## Task 1: NonceGenerator (CryptoKit)

**Files:** Create `AtollCard/Features/Auth/NonceGenerator.swift`; Test `AtollCardTests/NonceGeneratorTests.swift`.

- [ ] **Step 1: Failing test**
```swift
import XCTest
@testable import AtollCard

final class NonceGeneratorTests: XCTestCase {
    func test_sha256KnownVector() {
        XCTAssertEqual(NonceGenerator.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func test_randomNonceLengthAndCharset() {
        let n = NonceGenerator.randomNonceString(length: 32)
        XCTAssertEqual(n.count, 32)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        XCTAssertTrue(n.allSatisfy { allowed.contains($0) })
    }
    func test_randomNonceIsUnique() {
        XCTAssertNotEqual(NonceGenerator.randomNonceString(), NonceGenerator.randomNonceString())
    }
}
```

- [ ] **Step 2: Run → FAIL** (`NonceGenerator` undefined).

- [ ] **Step 3: Implement** `AtollCard/Features/Auth/NonceGenerator.swift`
```swift
import Foundation
import CryptoKit

enum NonceGenerator {
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var result = ""
        var remaining = length
        while remaining > 0 {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard status == errSecSuccess else { continue }
            if Int(byte) < charset.count {
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
```
Note: `charset.count` ist 64, also nimmt der `< 64`-Filter jedes Byte ohne Modulo-Bias.

- [ ] **Step 4: Run → PASS** (3 Tests).

- [ ] **Step 5: Commit**
```bash
git add AtollCard/Features/Auth/NonceGenerator.swift AtollCardTests/NonceGeneratorTests.swift
git commit -m "feat(ios): nonce generator (random + sha256) for Sign in with Apple

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Auth-Naht auf Apple id-token umstellen

**Files:** Modify `AtollCard/Features/Auth/AuthViewModel.swift`, `AtollCard/Stores/SupabaseAuthenticator.swift`, `AtollCard/Stores/AppStores.swift`; Test `AtollCardTests/AuthViewModelTests.swift` (ersetzen).

Kontext: `Authenticating.signIn(email:password:)` wird durch `signIn(idToken:nonce:)` ersetzt. Alle Aufrufer (SignInView in Task 4, AppStores.preview) ziehen nach.

- [ ] **Step 1: Test umschreiben** `AtollCardTests/AuthViewModelTests.swift`
```swift
import XCTest
@testable import AtollCard

@MainActor
final class AuthViewModelTests: XCTestCase {
    func test_signedOutByDefault() {
        let vm = AuthViewModel(authenticator: FakeAuthenticator())
        XCTAssertFalse(vm.isSignedIn)
        XCTAssertNil(vm.userId)
    }
    func test_signInSetsUserId() async {
        let id = UUID()
        let vm = AuthViewModel(authenticator: FakeAuthenticator(result: .success(id)))
        await vm.signIn(idToken: "tok", nonce: "n")
        XCTAssertTrue(vm.isSignedIn)
        XCTAssertEqual(vm.userId, id)
    }
    func test_signInFailureSetsError() async {
        let vm = AuthViewModel(authenticator: FakeAuthenticator(result: .failure(
            NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad token"]))))
        await vm.signIn(idToken: "tok", nonce: "n")
        XCTAssertFalse(vm.isSignedIn)
        XCTAssertEqual(vm.errorMessage, "bad token")
    }
}

struct FakeAuthenticator: Authenticating {
    var result: Result<UUID, Error> = .failure(NSError(domain: "x", code: 0))
    func signIn(idToken: String, nonce: String) async throws -> UUID { try result.get() }
    func signOut() async throws {}
}
```

- [ ] **Step 2: Run → FAIL** (Protokoll/Signatur stimmt nicht).

- [ ] **Step 3: AuthViewModel umstellen** `AtollCard/Features/Auth/AuthViewModel.swift`
```swift
import Foundation

protocol Authenticating {
    func signIn(idToken: String, nonce: String) async throws -> UUID
    func signOut() async throws
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var userId: UUID?
    @Published var errorMessage: String?

    var isSignedIn: Bool { userId != nil }
    private let authenticator: Authenticating

    init(authenticator: Authenticating) { self.authenticator = authenticator }

    func signIn(idToken: String, nonce: String) async {
        do {
            userId = try await authenticator.signIn(idToken: idToken, nonce: nonce)
            errorMessage = nil
        } catch {
            userId = nil
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await authenticator.signOut()
        userId = nil
    }
}
```

- [ ] **Step 4: SupabaseAuthenticator umstellen** `AtollCard/Stores/SupabaseAuthenticator.swift`
```swift
import Foundation
import Supabase

struct SupabaseAuthenticator: Authenticating {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func signIn(idToken: String, nonce: String) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        return session.user.id
    }
    func signOut() async throws { try await client.auth.signOut() }
}
```
Falls die SDK-Signatur abweicht (z. B. `OpenIDConnectCredentials`-Label), an die echte supabase-swift-2.48-API anpassen und melden.

- [ ] **Step 5: PreviewAuthenticator anpassen** in `AtollCard/Stores/AppStores.swift`
```swift
struct PreviewAuthenticator: Authenticating {
    var userId: UUID = UUID()
    func signIn(idToken: String, nonce: String) async throws -> UUID { userId }
    func signOut() async throws {}
}
```
(Rest von `AppStores` unverändert.)

- [ ] **Step 6: Run VM-Tests → PASS** (3). iOS-Build wird in Task 4 grün (SignInView nutzt noch alte API bis dahin — falls dieser Task isoliert gebaut wird, schlägt nur SignInView fehl; Task 2 gilt als grün, wenn `-only-testing:AtollCardTests/AuthViewModelTests` läuft und VM/Authenticator/Store kompilieren). Wenn der Gesamt-Build wegen SignInView bricht, ist das erwartet und wird in Task 4 behoben — in diesem Fall Task 2 + Task 4 zusammen committen.

- [ ] **Step 7: Commit**
```bash
git add AtollCard/Features/Auth/AuthViewModel.swift AtollCard/Stores/SupabaseAuthenticator.swift AtollCard/Stores/AppStores.swift AtollCardTests/AuthViewModelTests.swift
git commit -m "feat(ios): switch auth seam to Apple id-token (signInWithIdToken)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Entitlement + project.yml

**Files:** Create `AtollCard/AtollCard.entitlements`; Modify `project.yml`.

- [ ] **Step 1: Entitlement** `AtollCard/AtollCard.entitlements`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: project.yml** — im `AtollCard`-Target unter `settings.base` ergänzen:
```yaml
        CODE_SIGN_ENTITLEMENTS: AtollCard/AtollCard.entitlements
```
Dann `xcodegen generate`.

- [ ] **Step 3: Build beide Plattformen**
```
xcodebuild build -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: BUILD SUCCEEDED (signiert mit Team XK8V89P2QV, Entitlement aktiv). Falls macOS-Signing meckert: mit `CODE_SIGNING_ALLOWED=NO` Kompilierung verifizieren und melden.

- [ ] **Step 4: Commit**
```bash
git add AtollCard/AtollCard.entitlements project.yml
git commit -m "feat(ios): Sign in with Apple entitlement (iOS+macOS)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: SignInView + Apple-Flow + ProfileNameUpdater

**Files:** Rewrite `AtollCard/Features/Auth/SignInView.swift`; Create `AtollCard/Features/Auth/ProfileNameUpdater.swift`.

- [ ] **Step 1: ProfileNameUpdater** `AtollCard/Features/Auth/ProfileNameUpdater.swift`
```swift
import Foundation
import Supabase

enum ProfileNameUpdater {
    /// Best-effort: schreibt display_name nach Erst-Login (Apple liefert fullName nur einmal).
    static func update(displayName: String, userId: UUID,
                       client: SupabaseClient = AtollSupabase.client) async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await client.from("profiles")
                .update(["display_name": trimmed])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            // best effort — Onboarding fragt den Karten-Namen ohnehin
        }
    }
}
```

- [ ] **Step 2: SignInView** `AtollCard/Features/Auth/SignInView.swift`
```swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("AtollCard")
                .font(.atoll(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            SignInWithAppleButton(.signIn) { request in
                let nonce = NonceGenerator.randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = NonceGenerator.sha256(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .frame(maxWidth: 320)
            if let msg = authVM.errorMessage {
                Text(msg).font(.atoll(size: 13)).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.appBG.ignoresSafeArea())
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            authVM.errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                authVM.errorMessage = "Apple-Anmeldung unvollständig."
                return
            }
            let fullName = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            Task {
                await authVM.signIn(idToken: idToken, nonce: nonce)
                if let uid = authVM.userId, !fullName.isEmpty {
                    await ProfileNameUpdater.update(displayName: fullName, userId: uid)
                }
            }
        }
    }
}
```

- [ ] **Step 3: `xcodegen generate`, dann Build + Tests beide Plattformen**
```
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: BUILD SUCCEEDED (iOS+macOS), alle Tests grün (E-Mail/PW-Tests entfielen in Task 2).

- [ ] **Step 4: Commit**
```bash
git add AtollCard/Features/Auth/SignInView.swift AtollCard/Features/Auth/ProfileNameUpdater.swift
git commit -m "feat(ios): Sign in with Apple button, nonce flow, first-login name capture

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Verifikationsgate

**Files:** keine (Verifikation).

- [ ] **Step 1: Volle Suite + beide Builds**
```
xcodegen generate
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: TEST SUCCEEDED, beide BUILD SUCCEEDED.

- [ ] **Step 2: App-Boot-Check**
App auf Simulator installieren + starten (`SUPABASE_URL`/`SUPABASE_ANON_KEY` via Scheme-Env), bootet zu SignInView mit Apple-Button, kein Crash.

- [ ] **Step 3: Echter Apple-Login (manuell, Notiz)**
Voraussetzung: Sim/Gerät mit Apple-ID angemeldet UND Apple-Provider im Supabase-Prod-Dashboard aktiviert (Authorized Client IDs = `com.weckherlin.atollcard,com.weckherlin.atollcard.web`). Dann Button → Apple-Dialog → Session → RootTabView. Persistenz: `select id, display_name from profiles;` zeigt den neuen Nutzer.

---

## Self-Review
- **Spec-Abdeckung:** Nonce (T1), Naht-Umbau/`signInWithIdToken` (T2), Entitlement iOS+macOS (T3), Button+Flow+Name-Capture (T4), Verifikation (T5), lokale `config.toml` bereits gesetzt. E-Mail/PW entfällt (T2). ✓
- **Platzhalter:** keine; alle Schritte mit vollständigem Code. ✓
- **Typkonsistenz:** `Authenticating.signIn(idToken:nonce:)` identisch in Protokoll (T2), Fake (T2), `SupabaseAuthenticator` (T2), `PreviewAuthenticator` (T2), VM-Aufruf (T2) und View (T4). `NonceGenerator.randomNonceString`/`sha256` (T1) wie in View genutzt. ✓
- **Offen/M4:** Prod-Apple-Provider-Toggle im Dashboard (manuell, kein Token); echte Anon-Key/URL via xcconfig für Prod-Build.
