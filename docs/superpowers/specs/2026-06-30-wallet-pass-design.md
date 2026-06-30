# Wallet-Pass (Bau) — Design

**Datum:** 2026-06-30
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 7.** Karte als signierten Apple-Wallet-Pass (`.pkpass`) zu Wallet hinzufügen. Cert-Pipeline ist erledigt (Pass-Cert/Key/WWDR + `PASS_TYPE_ID=pass.swiss.atoll.card.persona` + `APPLE_TEAM_ID=XK8V89P2QV` als Supabase-Secrets gesetzt).

## Ziel
Nutzer tippt „Zu Wallet hinzufügen" → App holt einen serverseitig signierten `.pkpass` der aktiven Karte → `PKAddPassesViewController` fügt ihn zu Wallet hinzu. Pass zeigt Name/Titel/Firma + QR auf das öffentliche Profil.

## A. Edge Function `generate-pass` (Deno, `supabase/functions/generate-pass/`)
- Authed: liest `Authorization`-Header (User-JWT), erstellt Supabase-Client mit diesem Header (RLS-scoped) → lädt `cards` + `card_fields` für die übergebene `cardId` (RLS liefert nur eigene Karte). Kein JWT / fremde Karte → 401/leeres Ergebnis → Fehler.
- Baut `pass.json` (**generic**): `passTypeIdentifier`/`teamIdentifier` (Secrets), `serialNumber`=cardId, `organizationName`="AtollCard", `description`="AtollCard", `barcodes`=[{format:`PKBarcodeFormatQR`, message:`https://card.atoll-os.com/<slug>`, messageEncoding:`iso-8859-1`}], `generic.primaryFields`=[name], `secondaryFields`=[title, company], `auxiliaryFields`=Kontaktfelder, `backgroundColor`=rgb aus `accentColor`, `foregroundColor`/`labelColor`=weiß.
- Bilder: minimal `icon.png` + `icon@2x.png` (eingebettetes solides PNG, base64-Konstante) — Apple verlangt `icon.png`.
- `manifest.json` = `{ "<file>": "<sha1hex>" }` für alle Dateien. `signature` = **PKCS#7 detached CMS** über `manifest.json` (Pass-Cert + Key signieren, WWDR in Kette, sha256), via `npm:node-forge`. `.pkpass` = ZIP (pass.json, icon.png, icon@2x.png, manifest.json, signature) via `npm:fflate`. Antwort: `application/vnd.apple.pkpass` (base64 oder binär).
- CORS-Header für App-Invoke.

## B. iOS Add-Flow
- `AtollCard/Features/Share/WalletService.swift`: Protokoll `WalletPassProviding { func passData(forCardId: UUID) async throws -> Data }` + `SupabaseWalletService` (ruft `client.functions.invoke("generate-pass", options: .init(body: ["cardId": id]))` → Data). Naht → testbar mit Fake.
- `AtollCard/Features/Share/AddPassView.swift` (iOS): `UIViewControllerRepresentable` um `PKAddPassesViewController(pass: PKPass(data:))`. macOS: kein Wallet → Zeile nur unter `#if os(iOS)`.
- Einstieg: `ShareSheet` „Zu Wallet hinzufügen" (iOS-only) → holt Pass via `WalletService` → präsentiert Add-Sheet. Fehler → kurze Meldung.

## C. Tests / Verifikation
- Deno: reine `buildPassJSON(card, fields)`-Funktion unit-getestet (`deno test`) — Felder-Mapping, Barcode-URL, Farben.
- iOS: `WalletService`-Fake-Test (invoke-Naht); `PKAddPasses`-UI nicht unit-testbar; bestehende Suite grün; iOS+macOS Build grün.
- **Controller-Gate:** Function via MCP deployen; unauth-Invoke → 401 (deployed + auth-gated); `.pkpass`-Struktur lokal prüfen (entpacken: pass.json/manifest/signature vorhanden, signature ist PKCS#7).
- **Echt-Gate (du):** in der App „Zu Wallet hinzufügen" auf dem iPad → Pass landet in Wallet. (Signatur-Akzeptanz final erst hier.)

## Risiko / offen
- Apple-akzeptierte CMS-Signatur ist der Knackpunkt; falls Wallet ablehnt, iteriere ich an `signManifest` (sha1↔sha256, authenticatedAttributes, WWDR-Kette). Secrets sind gesetzt → schnelle Iteration möglich.
- Voller authed Pass-Build serverseitig nur mit echtem User-JWT testbar → dein iPad-Test ist das End-Gate.

## Bewusst nicht hier
Pass-Updates/Push (`webServiceURL`/registrations); NFC-Pässe; Logo-Bild-Upload in den Pass; macOS-Wallet; mehrere Pass-Stile.
