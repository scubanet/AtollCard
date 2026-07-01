# Konto löschen (In-App) — Design

**Datum:** 2026-07-01
**Status:** freigegeben (Dialog-Variante: zweistufig)
**App-Store-Pflicht** (Guideline 5.1.1(v)): Apps mit Account-Erstellung müssen In-App-Kontolöschung bieten. Erfüllt zugleich DSGVO-Löschpflicht.

## Ziel
Settings → „Konto löschen" → zweistufige Bestätigung → Edge Function löscht Storage-Medien + auth-User (DB cascadet) → App landet ausgeloggt auf SignInView.

## A. Edge Function `delete-account` (Deno, `supabase/functions/delete-account/`)
- `verify_jwt: true`. Aus dem Caller-JWT die User-ID lesen (`supabase.auth.getUser()` mit dem Authorization-Header) — es wird ausschließlich das **eigene** Konto gelöscht; keine Parameter von außen.
- Service-Role-Client (`SUPABASE_SERVICE_ROLE_KEY`, auto-injiziert):
  1. Storage: alle Objekte unter `card-media/<uid>/` listen (rekursiv über die Karten-Unterordner) + `remove()`.
  2. `auth.admin.deleteUser(uid)` → FK-Cascade räumt `profiles` → `cards` → `card_fields`/`card_events`/`connections`.
- Antwort 200 `{ok:true}`; Fehler 4xx/5xx mit Meldung. CORS wie `generate-pass`.

## B. iOS
- `Authenticating`-Protokoll + `deleteAccount() async throws`; Implementierungen:
  - `SupabaseAuthenticator`: `client.functions.invoke("delete-account")` (Void-Variante reicht; wirft bei non-2xx), danach lokal `try? await client.auth.signOut()` (Session wegräumen).
  - `PreviewAuthenticator` + Test-Fakes: no-op/Result.
- `AuthViewModel.deleteAccount() async`: ruft Authenticator; Erfolg → wie Sign-out (`userId=nil`, `AtollAppGroup.save(nil)`, Widget-Reload); Fehler → `errorMessage`.
- `SettingsView` „Konto"-Sektion: destruktive Zeile **„Konto löschen"** → Stufe 1 `confirmationDialog` („Konto löschen?") → Stufe 2 `alert` („Wirklich? Alle Karten & Kontakte werden unwiderruflich gelöscht.") → `await authVM.deleteAccount()`; Lade-Zustand während des Calls.

## C. Tests / Verifikation
- iOS: `AuthViewModelTests` + `deleteAccount` (Fake): Erfolg → `userId` nil; Fehler → `errorMessage` gesetzt, `userId` bleibt. Bestehende 47 Tests grün; iOS+macOS Build grün.
- Edge: Deploy via MCP; unauth → 401. **Cascade-E2E lokal** (`supabase start`): Test-User + Karte + Storage-Objekt anlegen → Function lokal aufrufen (`supabase functions serve`) oder Löschlogik per Service-Role-Skript nachstellen → user/cards/connections/storage weg.
- Interaktiv (du): Settings → Konto löschen auf dem iPad → landet auf SignInView; erneuter Apple-Login erzeugt frisches Konto.

## Bewusst nicht hier
Grace-Period/Soft-Delete; E-Mail-Bestätigung; Export vor Löschung (DSGVO-Portabilität = separat, M3+).
