# Link-Sicherheit (Scheme-Allowlist) — Design

**Datum:** 2026-06-29
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 6 (Security).** Verhindert `javascript:`/`data:`-Scheme in gerenderten Links aus nutzergelieferten `url`/`social`-Feldwerten. Hauptziel: stored-XSS auf dem öffentlichen Web-Profil.

## Problem
`web/src/render.ts` → `fieldRow()` setzt für `url`/`social`-Felder `href = value` (nur HTML-escaped). Ein Karten-Owner kann ein url-Feld auf `javascript:alert(1)` setzen; auf dem **öffentlichen** Profil `card.atoll-os.com/<slug>` wird daraus ein klickbarer `javascript:`-Link → Script-Ausführung im atoll-os.com-Origin, wenn ein fremder Betrachter klickt (stored XSS). `escapeHTML` verhindert nur Attribut-Breakout, nicht das gefährliche Scheme.

Sekundär: `EmailSignatureBuilder` (iOS) baut den url-Feld-`<a href>` aus dem Rohwert — in E-Mail-Clients ist `javascript:` zwar inert, aber Scheme-Allowlist ist saubere Hygiene (und war als Task-1-Notiz geflaggt).

## Nicht betroffen (geprüft)
- iOS `BusinessCardView`: nutzt nur `photoURL`/`coverURL` für `AsyncImage` (eigene Medien-Uploads), keine arbiträren url-Feld-Links.
- iOS `ConnectionDetailView`: nur feste `mailto:`/`tel:`-Schemes aus Lead-Werten — kein Scheme-Injection-Vektor.
- Web Cover/Foto: bereits über `safeURL()` (http/https-only) gefiltert.

## A. Web `fieldRow` (`web/src/render.ts`)
- `email` → `mailto:<encodeURIComponent(value)>`; `phone` → `tel:<value ohne Whitespace>`.
- `url`/`social` → Link nur, wenn `safeURL(value)` (existierende http/https-Allowlist) ein gültiges Ergebnis liefert; sonst als **Plain-Text** rendern (kein `<a>`, Wert bleibt sichtbar via `escapeHTML`).
- `custom`/`address` → bleiben Plain-Text (kein href) — falls aktuell ein href gesetzt wird, entfernen.
- vitest: url-Feld mit `javascript:alert(1)` → Markup enthält **kein** `href="javascript`, der Wert erscheint als Text; gültige `https://…` → `<a href="https://…`. `social` analog.

## B. iOS `EmailSignatureBuilder` (`AtollCard/Features/Share/EmailSignatureBuilder.swift`)
- Neuer privater Helfer `safeHref(_ value: String) -> String?` → gibt den Wert zurück, wenn er mit `http://`/`https://` beginnt (case-insensitiv, nach Trim), sonst `nil`.
- `url`-Feld: `<a href>` nur wenn `safeHref` ≠ nil; sonst Plain-Text (`label: value`).
- `phone`-Feld: `tel:`-Href ohne Whitespace (`value.filter { !$0.isWhitespace }` für den href; Anzeigewert bleibt original).
- `email` unverändert (`mailto:`).
- XCTest: url-Feld `javascript:alert(1)` → HTML enthält **kein** `<a href="javascript`, Wert als Text; `https://x.io` → `<a href="https://x.io`. phone `"+41 79 123"` → href `tel:+4179123` (ohne Spaces), Anzeige `+41 79 123`.

## Tests / Verifikation
- Web: `cd web && npm test` grün (neue fieldRow-Tests + bestehende).
- iOS: `EmailSignatureBuilderTests` erweitert; volle iOS-Suite + iOS/macOS Build grün.

## Bewusst nicht hier
- Gemeinsamer Web↔iOS-Allowlist-Code (zwei kleine, sprachspezifische Helfer genügen — DRY über Sprachgrenzen lohnt nicht).
- Editor-seitige Eingabevalidierung (Allowlist beim Speichern) — Rendering-seitige Absicherung ist der robuste Ort; Editor-Validierung wäre nur UX-Zucker, später.
- `data:`-Bilder o.ä.; weitergehende CSP-Header (separater Web-Infra-Task).
