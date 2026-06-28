# AtollCard — Handoff für Claude Code

## Status (Stand 2026-06-28)

**Fertig & verifiziert (in Cowork gebaut):**
- `web/` komplett implementiert nach M1-Web-Plan. **`npm test` → 23/23 grün**, `vite build` grün.
  - Module: slug, vcard (3.0 + Escaping), api (get_public_card/record_card_event-Wrapper), render (Glas-UI, Akzent, Cover/Avatar, HTML-Escaping + URL/Hex-Validierung), download (vCard-Blob), consent (DSGVO-Gate).
  - Stylesheet `web/src/style.css` adoptiert die Mockup-Tokens (Manrope, Glas, Akzent).
- `supabase/migrations/0001–0007` + `supabase/tests/0001–0004` geschrieben nach M1-Backend-Plan (inkl. `label`/`accent_color`/`cover_url`, Storage-Bucket `card-media`).

**NICHT hier ausführbar (kein Docker/Xcode im Cowork-Sandkasten) → in Claude Code auf dem Mac:**
1. `cd web && npm install` (node_modules wurden nicht übertragen).
2. Backend verifizieren: `supabase start && supabase db reset && supabase test db` (erwartet pgTAP grün).
3. iOS-App: M1-iOS-Plan ab Task 0 (Xcode-Projekt erzeugen), dann Tasks 1–12. Spezialisten: Sierra (iOS), Hexa (Backend), Felix (Web), Vex (RLS-Audit).

## Verträge (über alle Schichten identisch)
- Profil-URL: `https://card.atoll-os.com/<slug>`.
- RPC `get_public_card(p_slug)` → `public_card`(display_name,title,company,theme,accent_color,cover_url,logo_url,photo_url,fields jsonb).
- RPC `record_card_event(p_slug,p_type,p_coarse_geo)`; event-Typen: view|tap|save|share.
- Storage-Bucket `card-media`, Pfad `<owner_id>/<card_id>/{cover|photo}`.

## Nächste Pläne (noch nicht geschrieben)
M2 (Kontakte-Empfang, Wallet, NFC, Widget, Watch, Signatur), M3 (Team/Analytics), M4 (StoreKit/Store).
