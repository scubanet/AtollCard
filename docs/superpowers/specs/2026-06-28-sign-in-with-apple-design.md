# Sign in with Apple — Design (ersetzt E-Mail/Passwort)

**Datum:** 2026-06-28
**Status:** Entwurf zur Freigabe
**Kontext:** M1 ist fertig (Backend/Web/iOS verifiziert). Dieses Feature ersetzt den E-Mail/Passwort-Login der iOS/macOS-App durch „Sign in with Apple" (nativ) und verdrahtet ein gehostetes Supabase-Prod-Projekt.

## Ziel
Nutzer melden sich ausschließlich per Apple-Account an. Native iOS/macOS-Flow über `AuthenticationServices` → Supabase `signInWithIdToken(provider: .apple)`. E-Mail/Passwort-UI entfällt.

## Apple-Identifier (kein Secret im Repo)
| Zweck | Wert |
|---|---|
| Bundle ID / nativer Client | `com.weckherlin.atollcard` |
| Services ID (Web-Flow, optional) | `com.weckherlin.atollcard.web` |
| Team ID | `XK8V89P2QV` |
| Key ID (Sign-in-Key, für späteren Web-Flow) | `ZS7M72CAK5` |
| `.p8` Private Key | **nicht im Repo** — nur lokal/Dashboard |

Apple Developer Portal ist erledigt: App-ID hat „Sign in with Apple"; Services ID + Key (.p8) angelegt für späteren Web-Flow/Relay.

## Supabase-Prod-Projekt
- Ref `bhkeplfkuismwyfiqcga` (Name „AtollCard", eu-west-1, PG17), aktuell leer.
- Schritte: warten bis `ACTIVE_HEALTHY` → `supabase link --project-ref bhkeplfkuismwyfiqcga` → `supabase db push` (Migrationen 0001–0007) → Apple-Provider aktivieren.
- **Nativ braucht nur Authorized Client IDs** (`com.weckherlin.atollcard`, optional `.web`) — **kein `.p8`-Secret**. Secret/JWT nur für Web-Flow (später).

## Architektur (Client)

### Naht-Umbau
`Authenticating`-Protokoll ändert sich:
- alt: `signIn(email:password:) async throws -> UUID`
- neu: `signIn(idToken: String, nonce: String) async throws -> UUID` + `signOut()`

`SupabaseAuthenticator.signIn(idToken:nonce:)` → `client.auth.signInWithIdToken(.init(provider: .apple, idToken: idToken, nonce: nonce))`, gibt `session.user.id` zurück. `AuthViewModel` bekommt `signIn(idToken:nonce:) async` (setzt `userId`/`errorMessage`), bleibt mit Fake testbar.

### Apple-Flow (View-Schicht, dünn, untestbar — wie SupabaseCardStore)
- `SignInView` rendert `SignInWithAppleButton` (SwiftUI, cross-platform), Scopes `[.fullName, .email]`.
- **Nonce (Pflicht):** `NonceGenerator` erzeugt Roh-Nonce (zufällig, ≥32 Zeichen) und liefert dessen SHA256-Hex. `request.nonce = sha256(raw)`; nach Erfolg Roh-Nonce an `signIn(...)`. Verhindert Replay.
- On success: aus `ASAuthorizationAppleIDCredential` `identityToken` (→ String) + Roh-Nonce an die VM. Wenn `fullName` vorhanden (nur Erst-Login) → nach Sign-in `profiles.display_name` per authentifiziertem Update setzen (RLS „update own" erlaubt). Fehlt er, kein Problem (Onboarding fragt Karten-Namen).

### Entitlement
Neue `AtollCard/AtollCard.entitlements`:
```xml
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
```
In `project.yml` für iOS **und** macOS, Debug+Release (`CODE_SIGN_ENTITLEMENTS`).

## Supabase lokal
`supabase/config.toml`:
```toml
[auth.external.apple]
enabled = true
client_id = "com.weckherlin.atollcard"
```
(Native Token-Audience = Bundle ID. Kein Secret lokal nötig.)

## Komponenten / Isolation
- `NonceGenerator` (CryptoKit): rein, unit-testbar (random + sha256-hex).
- `Authenticating` / `SupabaseAuthenticator`: Naht; nur Authenticator importiert SDK.
- `AuthViewModel`: Zustand, testbar mit Fake.
- `SignInView` + `AppleSignInButton`-Wrapper: dünne View, macht ASAuthorization + Nonce, ruft VM. Nicht unit-getestet (Framework-UI).
- `ProfileNameUpdater` (klein): schreibt `display_name` nach Erst-Login (best effort).

## Fehlerbehandlung
- Apple-Abbruch/`.canceled` → keine Fehlermeldung (stiller Abbruch).
- Apple-Fehler / fehlendes Token → `errorMessage`.
- Supabase-Fehler → `errorMessage` (localizedDescription).
- `profiles.display_name`-Update schlägt fehl → ignorieren (nicht blockieren).

## Tests
- `NonceGeneratorTests`: sha256-Hex korrekt (bekannter Vektor), Roh-Nonce-Länge/Zeichensatz.
- `AuthViewModelTests` (umgebaut): `signIn(idToken:nonce:)` Erfolg setzt `userId`; Fehler setzt `errorMessage`; signedOut by default. Fake-Authenticator-Signatur angepasst.
- Bestehende E-Mail/PW-VM-Tests entfallen (Feature ersetzt).
- Build iOS+macOS grün. Gesamt-Testsuite grün.

## Verifikation (E2E)
- Lokal: Sim mit Apple-ID angemeldet → Button → echter Apple-Dialog → Session → CardList. (Sim-Apple-ID nötig.)
- Prod: nach `db push` + Provider-Config gegen `bhkeplfkuismwyfiqcga` testen.

## Bewusst nicht in diesem Feature
- Web-Flow / Apple-E-Mail-Relay (Key/.p8 vorhanden, später).
- Account-Löschung-Webhook (Server-to-Server endpoint leer gelassen).
- Migration bestehender E-Mail/PW-Nutzer (es gibt keine Prod-Nutzer).
