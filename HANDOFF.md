# AtollCard — Handoff für Claude Code

## Status (Stand 2026-06-28)

**M1 vollständig + Sign in with Apple implementiert & verifiziert auf dem Mac.**

### Sign in with Apple (Stand 2026-06-28, ersetzt E-Mail/Passwort)
- Client: nativer `SignInWithAppleButton` + Nonce (zufällig+SHA256) → `signInWithIdToken(.apple)`; Naht `Authenticating.signIn(idToken:nonce:)`; Apple-`fullName`→`profiles.display_name` (best effort). Entitlement `com.apple.developer.applesignin` (iOS+macOS). **22 Tests grün**, beide Builds grün, App bootet zu „Mit Apple anmelden". Spec/Plan unter `docs/superpowers/`.
- Apple Developer Portal erledigt: App-ID-Capability, Services ID `com.weckherlin.atollcard.web`, Key `ZS7M72CAK5` (Team `XK8V89P2QV`), `.p8` beim Owner.
- **Prod-Supabase** (`bhkeplfkuismwyfiqcga`, eu-west-1): Migrationen 0001–0008 via MCP angewandt, Advisor-Hardening (`handle_new_user` execute revoked), live anon-Kontrakt verifiziert. Lokal `config.toml [auth.external.apple]` aktiviert.
- **Verifiziert (2026-06-28):** Apple-Provider im Prod-Dashboard aktiv (Client IDs gesetzt, Secret = ES256-JWT aus `.p8`, läuft **2026-12-25** ab → vor dann neu generieren mit `scratchpad/apple_secret.py`-Muster). Echter Apple-Login auf Sim grün. App-Default zeigt auf Prod `https://bhkeplfkuismwyfiqcga.supabase.co` (anon key in `SupabaseClient+Atoll.swift`, env-überschreibbar für lokal).
- **M4-Rest:** Anon-Key/URL ggf. via xcconfig statt hartkodiert; Apple-Secret-Rotation (6-Monats-Ablauf).

### M2 Sub-1 — Karten-Medien + Edit-Fixes (Stand 2026-06-28)
- Cover + Profilfoto via `PhotosPicker` → `ImageDownscaler` (ImageIO, 1600/512px) → `MediaStoring`/`SupabaseMediaStore` → `card-media`-Bucket; Anzeige auf `BusinessCardView` (AsyncImage Foto rund + Cover-Hintergrund, Initialen/Gradient als Fallback). **26 Tests grün, iOS+macOS Build grün.**
- Backlog-Fixes: `CardEditorViewModel` erhält bestehende Media-URLs beim Edit (Regressionstest); `slug_available`-RPC (Migration 0009, anon revoked) + `SupabaseCardStore.slugIsAvailable` nutzt sie. 0009 auf Prod live + verifiziert.
- **OFFEN:** interaktiver Foto-Smoke (Foto wählen→speichern→Karte zeigt Bild, Objekt im Prod-Bucket). `coverURL/photoURL` im VM sind `var` (nicht `@Published`) — „Entfernen" nutzt `.id()`-Refresh; bei Bedarf auf `@Published` heben. Lokales Supabase braucht `db reset` für Apple-Config + 0009 (nur Prod angewandt).
- M2-Reste: Wallet/NFC/Widget/Watch, Signatur, Dark Mode/A11y, card-media privater Bucket.

### M2 Sub-2 — Kontakte-Empfang / Lead-Capture (Stand 2026-06-29)
- Web-Profil: „Verbinden"-Formular (Name/E-Mail/Telefon/Firma/Nachricht + Consent-Checkbox) → anon `record_connection`-RPC. **29 Web-Tests grün.**
- Backend: `connections`-Tabelle + RLS (owner-only-read) + `record_connection` (Migration 0010, public Cards). **pgTAP 5/5 grün (lokal), Prod live + RLS verifiziert** (anon select `[]`, direct insert 401, RPC no-op 204). Lead-Pfad E2E lokal grün.
- iOS: `Connection`-Model, `ConnectionStoring`-Naht + Supabase/InMemory, `ConnectionsViewModel`, Kontakte-Tab (Liste + Detail mit tap-to-call/mail) ersetzt Placeholder. **28 iOS-Tests grün, iOS+macOS Build grün.**
- **OFFEN / Risiko:** iOS-Decode von `created_at` (6-stellige Microseconds, z. B. `…45.749719+00:00`) — supabase-swift-Decoder sollte passen; falls Decode-Fehler beim echten Lead-Abruf → `Connection.createdAt` auf String oder custom decoder umstellen. Interaktiver Check (echten Lead anlegen → erscheint im Kontakte-Tab).
- Bewusst nicht: App-zu-App-Austausch, Geräte-Adressbuch-Export (CNContact), Push bei neuem Lead, Lead-Löschen/Tags.

---

**M1 vollständig implementiert & verifiziert auf dem Mac.**

- **Backend** (`supabase/`): Migrationen 0001–0007 + pgTAP 0001–0004. `supabase db reset` grün, `supabase test db` → **17/17 PASS**. TS-Typen generiert. Vex-RLS-Audit grün (`supabase/SECURITY-NOTES.md`), live anon-RPC-Kontrakt verifiziert (`get_public_card`/`record_card_event`).
- **Web** (`web/`): `npm install` + `npm test` → **23/23 grün**, `vite build` grün. Live-Kontrakt gegen lokales Supabase über PostgREST geprüft.
- **iOS/macOS** (`AtollCard/`): Tasks 0–12 per TDD (subagent-driven-development). **19 Unit-Tests grün**, iOS- **und** macOS-Build grün. End-to-end gegen lokales Supabase verifiziert (auth signup → owner-insert/list, Slug-Unique 409, RLS, Public-RPC). App bootet auf Simulator zu SignInView.
  - Xcode-Projekt via **XcodeGen** (`project.yml` = Source of Truth; `*.xcodeproj` ist gitignored — `xcodegen generate` regeneriert es). supabase-swift 2.48.0 via SPM. Swift-Sprachmodus 5.0. Manrope gebündelt + zur Laufzeit registriert.

### Lokale Verifikation (Befehle)
```bash
# Backend (Docker Desktop nötig)
supabase start && supabase db reset && supabase test db
# Web
cd web && npm install && npm test
# iOS + macOS
xcodegen generate
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Hinweis: Der Homebrew-`supabase`-Wrapper enthielt ein arm64-Binary mit ungültiger Signatur (killed:9). Falls erneut: `codesign --force --sign - <…/@supabase/cli-darwin-arm64/bin/supabase>`.

## Verträge (über alle Schichten identisch)
- Profil-URL: `https://card.atoll-os.com/<slug>`.
- RPC `get_public_card(p_slug)` → `public_card`(display_name,title,company,theme,accent_color,cover_url,logo_url,photo_url,fields jsonb).
- RPC `record_card_event(p_slug,p_type,p_coarse_geo)`; event-Typen: view|tap|save|share.
- Storage-Bucket `card-media`, Pfad `<owner_id>/<card_id>/{cover|photo}` (lowercase — owner-folder-RLS vergleicht `auth.uid()::text`).

## M2-Backlog (Review-Funde, bewusst nach M1 verschoben)
Aus Code-Review + Vera-QA-Gate; M1-plankonform belassen, hier dokumentiert:
- **Slug-Verfügbarkeit cross-user:** `SupabaseCardStore.slugIsAvailable` sieht via RLS nur eigene Karten → fremder Slug kollidiert erst am DB-Unique (gefangener Fehler). Fix M2: `SECURITY DEFINER`-RPC `slug_available(text)`.
- **Media-URL-Erhalt:** `CardEditorViewModel.save()` setzt `coverURL/logoURL/photoURL = nil`; sobald MediaStore-Upload (M2) verdrahtet wird, vorher die bestehenden URLs in den VM laden und durchreichen (sonst stilles Nullen).
- **Accessibility-Härtung (Vera GL-003):** Dynamic Type (`Font.custom(..., relativeTo:)`), Color-Sets + Dark Mode statt `Color(hex:)`, Reduce-Motion/Transparency-Fallbacks, `text2`-Kontrast (#8A8F98 = 2.83:1 — Mockup-Treue vs. WCAG, Iris-Entscheid). Floating-Tabbar Safe-Area-Inset.
- **Vex R-1 (MEDIUM):** `card-media` ist public-read → Medien privater Karten per URL erreichbar. Vor „echt privat“ in M2 auf private Bucket + signed URLs.
- Kleinkram: `CardListView`/`CardEditorView` (Task-8-Basis-Forms) sind unstyled — durch Shell-Pendants ersetzen oder entfernen; Non-ASCII-Slug-Transliteration (`Müller`→`mller`).

## Nächste Pläne (noch nicht geschrieben)
M2 (Kontakte-Empfang, Wallet, NFC, Widget, Watch, Signatur, Bild-Upload-UI, Dark Mode/A11y), M3 (Team/Analytics), M4 (StoreKit/Store, Prod-Config via xcconfig).
