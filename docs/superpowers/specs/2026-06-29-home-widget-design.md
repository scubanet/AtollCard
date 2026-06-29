# Home-Screen Widget (Karte/QR) — Design

**Datum:** 2026-06-29
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 4.** WidgetKit-Home-Screen-Widget, das die aktive Karte als QR (zum Scannen) + Name zeigt. Self-contained, kein externes Cert (App Group reicht auf Sim; Gerät braucht Portal-Registrierung).

## Ziel
Nutzer legt ein AtollCard-Widget auf den Home-Screen: **small** = QR-Hero (jemand scannt direkt), **medium** = Name (+ Titel) + QR. Zeigt die zuletzt in der App gewählte aktive Karte. Tap öffnet die App.

## Entscheidungen
- Größen: **Home small + medium** (kein Lock-Screen).
- Datenquelle: **aktive Karte** via App Group (kein konfigurierbares Widget).
- Widget **iOS-only**; App bleibt iOS+macOS.

## A. App Group + Shared Snapshot
- App Group `group.com.weckherlin.atollcard`. Entitlement auf App **und** Widget-Extension. (Sim funktioniert ohne Portal; echtes Gerät braucht App-Group-Registrierung im Apple Developer Portal — Flag, analog SIWA-Entitlement.)
- `SharedCardSnapshot` (Codable): `slug: String`, `displayName: String`, `accentColor: String`. Liegt in einer Datei, die **beiden** Targets als Source angehört (xcodegen Multi-Target-Membership).
- `AtollAppGroup`:
  - `static let suiteName = "group.com.weckherlin.atollcard"`
  - `save(_ snapshot: SharedCardSnapshot?)` — schreibt JSON in `UserDefaults(suiteName:)` unter Key `activeCard` (nil → entfernt Key).
  - `load() -> SharedCardSnapshot?` — liest/decodiert.
  - Für Tests injizierbarer Suite-Name (Default `suiteName`).
- Schreib-Trigger: `RootTabView` schreibt den Snapshot der aktiven Karte (`selectedCard`) bei Erscheinen + bei Änderung von `selectedCardId`/`vm.cards`, ruft danach `WidgetCenter.shared.reloadAllTimelines()`. Sign-out (AuthViewModel) → `AtollAppGroup.save(nil)` + reload.

## B. Widget-Extension
- Neues Target `AtollCardWidget` in `project.yml`: `type: app-extension`, `supportedDestinations: [iOS]`, eigenes Entitlement (App Group), `DEVELOPMENT_TEAM` + automatic signing; als App-Extension in `AtollCard` (iOS) eingebettet (`dependencies: - target: AtollCardWidget` auf der App mit `embed: true`). Shared sources: `SharedCardSnapshot.swift`, `AtollAppGroup.swift`, `QRCodeGenerator.swift`, und der `Color(hex:)`-Init (entweder Theme.swift teilen oder ein kleiner shared `Color+Hex.swift` — siehe Plan).
- `Provider: TimelineProvider`: `placeholder`/`snapshot`/`timeline` liefern eine Entry mit dem aktuellen `SharedCardSnapshot?` (eine Entry, `.never`/lange Policy — Reload kommt vom App-Trigger).
- `AtollCardWidgetEntryView`:
  - **systemSmall**: QR füllt die Fläche (Padding), kein Text — oder winziges Name-Label unten. QR-Hero.
  - **systemMedium**: HStack — links Name (`.headline`) + optional Titel/Firma (`.caption`, `Theme.text2`-Äquivalent), rechts QR (quadratisch). Akzentfarbe aus Snapshot (`Color(hex:)`).
  - Kein Snapshot → Platzhalter „In AtollCard anmelden, um deine Karte zu zeigen." (System-Font, neutral).
- QR-Render: `QRCodeGenerator.image(for: QRCodeGenerator.profileURL(forSlug: snapshot.slug))` → `CIContext().createCGImage(_, from:)` → `Image(decorative: cgImage, scale: 1)`, `.interpolation(.none)`, `.accessibilityLabel("QR-Code für \(name)")`.
- Tap: Widget öffnet die App (default; kein custom deep link in dieser Runde).
- Font: System-Font im Widget (kein Manrope-Bundle in der Extension) — QR ist der Hero; Branding via Akzentfarbe.

## C. Tests
- `AtollCardTests/SharedCardSnapshotTests.swift`: Codable round-trip (encode→decode gleich).
- `AtollCardTests/AtollAppGroupTests.swift`: `save`→`load` round-trip + `save(nil)` löscht (mit einem Test-Suite-Namen, am Ende `removePersistentDomain` aufräumen).
- Widget-View nicht unit-getestet (WidgetKit-UI).

## D. Verifikation
- Build **App + AtollCardWidget-Extension (iOS)** grün; **macOS-App** grün (Widget iOS-only, kein macOS-Build der Extension); iOS-Tests grün (bestehende 30 + neue).
- Snapshot-E2E: App schreibt → `AtollAppGroup.load()` liefert dieselbe Karte (durch die Round-trip-Tests + manueller Check).
- Widget visuell auf dem Home-Screen = interaktiv (Sim-Widget-Hinzufügen nicht skriptbar) → Vera/Nutzer.

## Bewusst nicht hier
Lock-Screen-/StandBy-Widgets; konfigurierbares Widget (AppIntent); Manrope im Widget; custom Deep-Link-Routing; macOS-Widget; Live-QR-Aktualisierung über Zeitintervalle (Reload nur app-getrieben).
