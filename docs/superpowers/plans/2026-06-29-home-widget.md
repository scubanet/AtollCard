# Home-Screen Widget (Karte/QR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** WidgetKit-Home-Widget (small=QR-Hero, medium=Name+QR) zeigt die aktive Karte aus einer App Group.

**Architecture:** App schreibt einen `SharedCardSnapshot` in eine App-Group-UserDefaults-Suite; die Widget-Extension liest ihn und rendert QR (via geteiltem `QRCodeGenerator`) + Name. Shared-Code (Snapshot, AppGroup, QR, Color+Hex) gehört beiden Targets an.

**Tech Stack:** SwiftUI, WidgetKit, App Groups, CoreImage, XCTest, XcodeGen, Swift 5.

**Konventionen:** Repo `~/Developer/AtollCard`. Nach Änderungen `xcodegen generate`. iOS-Test `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`; App+Widget-Build `xcodebuild build -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` (baut die eingebettete Extension mit); macOS `-destination 'platform=macOS,arch=arm64'`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `AtollCard/Shared/Color+Hex.swift` — `Color(hex:)` (aus Theme.swift extrahiert; von App + Widget genutzt).
- `AtollCard/Shared/SharedCardSnapshot.swift` — Codable Snapshot der aktiven Karte.
- `AtollCard/Shared/AtollAppGroup.swift` — App-Group read/write.
- `AtollCard/AtollCard.entitlements` — App-Group ergänzen.
- `AtollCardWidget/AtollCardWidget.entitlements` — App-Group.
- `AtollCardWidget/AtollCardWidget.swift` — Widget, Provider, Entry, Views.
- `project.yml` — Widget-Target + Embed + shared sources.
- `AtollCard/Features/Shell/RootTabView.swift`, `AtollCard/App/AtollCardApp.swift` (oder AuthVM) — Snapshot-Schreib-Trigger.
- Tests: `AtollCardTests/SharedCardSnapshotTests.swift`, `AtollCardTests/AtollAppGroupTests.swift`.

---

## Task 1: Shared Snapshot + AppGroup + Color extraction

**Files:** Create `AtollCard/Shared/Color+Hex.swift`, `AtollCard/Shared/SharedCardSnapshot.swift`, `AtollCard/Shared/AtollAppGroup.swift`; Modify `AtollCard/DesignSystem/Theme.swift`; Test `AtollCardTests/SharedCardSnapshotTests.swift`, `AtollCardTests/AtollAppGroupTests.swift`.

- [ ] **Step 1: Failing tests**
`AtollCardTests/SharedCardSnapshotTests.swift`:
```swift
import XCTest
@testable import AtollCard

final class SharedCardSnapshotTests: XCTestCase {
    func test_codableRoundTrip() throws {
        let snap = SharedCardSnapshot(slug: "jane-doe", displayName: "Jane Doe", accentColor: "#0E7C86")
        let data = try JSONEncoder().encode(snap)
        let back = try JSONDecoder().decode(SharedCardSnapshot.self, from: data)
        XCTAssertEqual(back, snap)
    }
}
```
`AtollCardTests/AtollAppGroupTests.swift`:
```swift
import XCTest
@testable import AtollCard

final class AtollAppGroupTests: XCTestCase {
    private let suite = "group.test.atollcard"
    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }
    func test_saveThenLoadRoundTrips() {
        let snap = SharedCardSnapshot(slug: "s", displayName: "N", accentColor: "#0E7C86")
        AtollAppGroup.save(snap, suiteName: suite)
        XCTAssertEqual(AtollAppGroup.load(suiteName: suite), snap)
    }
    func test_saveNilClears() {
        let snap = SharedCardSnapshot(slug: "s", displayName: "N", accentColor: "#0E7C86")
        AtollAppGroup.save(snap, suiteName: suite)
        AtollAppGroup.save(nil, suiteName: suite)
        XCTAssertNil(AtollAppGroup.load(suiteName: suite))
    }
}
```

- [ ] **Step 2: Run → FAIL** (types missing).

- [ ] **Step 3: Extract `Color(hex:)`.** Create `AtollCard/Shared/Color+Hex.swift`:
```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }
}
```
Then REMOVE the `init(hex:)` from `AtollCard/DesignSystem/Theme.swift` (keep `init(light:dark:)` and the `Theme` enum there). Theme.swift still references `Color(hex:)` — now resolved from the new file (same module).

- [ ] **Step 4: `SharedCardSnapshot`** `AtollCard/Shared/SharedCardSnapshot.swift`:
```swift
import Foundation

struct SharedCardSnapshot: Codable, Equatable {
    var slug: String
    var displayName: String
    var accentColor: String
}
```

- [ ] **Step 5: `AtollAppGroup`** `AtollCard/Shared/AtollAppGroup.swift`:
```swift
import Foundation

enum AtollAppGroup {
    static let suiteName = "group.com.weckherlin.atollcard"
    private static let key = "activeCard"

    static func save(_ snapshot: SharedCardSnapshot?, suiteName: String = suiteName) {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let snapshot else { defaults?.removeObject(forKey: key); return }
        if let data = try? JSONEncoder().encode(snapshot) { defaults?.set(data, forKey: key) }
    }

    static func load(suiteName: String = suiteName) -> SharedCardSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedCardSnapshot.self, from: data)
    }
}
```

- [ ] **Step 6: Run → PASS** (3 tests). Full iOS suite + macOS build green (`Color(hex:)` still resolves app-wide).

- [ ] **Step 7: Commit**
```bash
git add AtollCard/Shared AtollCard/DesignSystem/Theme.swift AtollCardTests/SharedCardSnapshotTests.swift AtollCardTests/AtollAppGroupTests.swift
git commit -m "feat(ios): shared card snapshot + app group store (+ extract Color(hex:))

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Widget extension target + UI

**Files:** Modify `project.yml`, `AtollCard/AtollCard.entitlements`; Create `AtollCardWidget/AtollCardWidget.entitlements`, `AtollCardWidget/AtollCardWidget.swift`.

- [ ] **Step 1: App Group on the app entitlement** — `AtollCard/AtollCard.entitlements`, add inside `<dict>`:
```xml
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.weckherlin.atollcard</string>
    </array>
```
(Keep the existing `applesignin` key.)

- [ ] **Step 2: Widget entitlement** — `AtollCardWidget/AtollCardWidget.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.weckherlin.atollcard</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: `project.yml`** — add the widget target, embed it in the app, and the scheme builds it. Under `targets:` add:
```yaml
  AtollCardWidget:
    type: app-extension
    supportedDestinations: [iOS]
    sources:
      - AtollCardWidget
      - path: AtollCard/Shared/SharedCardSnapshot.swift
      - path: AtollCard/Shared/AtollAppGroup.swift
      - path: AtollCard/Shared/Color+Hex.swift
      - path: AtollCard/Features/Share/QRCodeGenerator.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.weckherlin.atollcard.widget
        SWIFT_VERSION: "5.0"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: AtollCard
        INFOPLIST_KEY_NSExtensionPointIdentifier: com.apple.widgetkit-extension
        CODE_SIGN_ENTITLEMENTS: AtollCardWidget/AtollCardWidget.entitlements
        DEVELOPMENT_TEAM: XK8V89P2QV
        CODE_SIGN_STYLE: Automatic
        TARGETED_DEVICE_FAMILY: "1,2"
```
On the `AtollCard` app target add a dependency that embeds the extension (under `targets: AtollCard:`):
```yaml
    dependencies:
      - package: Supabase
        product: Supabase
      - target: AtollCardWidget
        embed: true
```
(Merge with the existing `dependencies:` — keep the Supabase package dependency.)

- [ ] **Step 4: Widget code** `AtollCardWidget/AtollCardWidget.swift`:
```swift
import WidgetKit
import SwiftUI
import CoreImage

struct AtollEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedCardSnapshot?
}

struct AtollProvider: TimelineProvider {
    func placeholder(in context: Context) -> AtollEntry {
        AtollEntry(date: Date(), snapshot: SharedCardSnapshot(slug: "jane-doe", displayName: "Jane Doe", accentColor: "#0E7C86"))
    }
    func getSnapshot(in context: Context, completion: @escaping (AtollEntry) -> Void) {
        completion(AtollEntry(date: Date(), snapshot: AtollAppGroup.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AtollEntry>) -> Void) {
        let entry = AtollEntry(date: Date(), snapshot: AtollAppGroup.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private func qrImage(forSlug slug: String) -> Image? {
    guard let ci = QRCodeGenerator.image(for: QRCodeGenerator.profileURL(forSlug: slug)) else { return nil }
    let ctx = CIContext()
    guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
    return Image(decorative: cg, scale: 1)
}

struct AtollCardWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AtollEntry

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemSmall: small(snap)
            default: medium(snap)
            }
        } else {
            placeholder
        }
    }

    private func qr(_ slug: String, _ name: String) -> some View {
        Group {
            if let img = qrImage(forSlug: slug) {
                img.resizable().interpolation(.none).scaledToFit()
                    .accessibilityLabel("QR-Code für \(name)")
            } else {
                Image(systemName: "qrcode").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
    }

    private func small(_ snap: SharedCardSnapshot) -> some View {
        qr(snap.slug, snap.displayName).padding(10)
    }

    private func medium(_ snap: SharedCardSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.displayName).font(.headline).lineLimit(2)
                Text("card.atoll-os.com/\(snap.slug)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            qr(snap.slug, snap.displayName).frame(width: 96, height: 96)
        }
        .padding(14)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode").font(.title)
            Text("In AtollCard anmelden, um deine Karte zu zeigen.")
                .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AtollCardWidget: Widget {
    let kind = "AtollCardWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AtollProvider()) { entry in
            AtollCardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AtollCard")
        .description("Zeigt deine aktive Karte als QR-Code.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AtollCardWidgetBundle: WidgetBundle {
    var body: some Widget { AtollCardWidget() }
}
```

- [ ] **Step 5: Generate + build app (embeds widget)**
Run: `xcodegen generate && xcodebuild build -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' 2>&1 | grep -iE "error:|BUILD (SUCCEEDED|FAILED)" | tail -5`
Expected: BUILD SUCCEEDED (both AtollCard + AtollCardWidget compile, extension embedded). If the scheme doesn't build the widget, confirm the embed dependency pulled it in (it should). Report any signing/Info.plist error.
Also macOS app still builds: `xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64' ...` (the iOS-only widget is not part of the macOS build).

- [ ] **Step 6: Commit**
```bash
git add project.yml AtollCard/AtollCard.entitlements AtollCardWidget
git commit -m "feat(ios): WidgetKit extension — active card QR (small + medium)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: App writes snapshot + reloads widget

**Files:** Modify `AtollCard/Features/Shell/RootTabView.swift`; Modify `AtollCard/Features/Auth/AuthViewModel.swift` (sign-out clear).

- [ ] **Step 1: Write snapshot on active-card change.** In `RootTabView`, add `import WidgetKit`. Add a private helper:
```swift
    private func publishActiveCard() {
        if let c = selectedCard {
            AtollAppGroup.save(SharedCardSnapshot(slug: c.slug, displayName: c.displayName, accentColor: c.accentColor))
        } else {
            AtollAppGroup.save(nil)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
```
Call `publishActiveCard()` from the existing `.task`/load path (after `await vm.load()` and after the `selectedCardId` default is set) AND add `.onChange(of: selectedCardId) { _ in publishActiveCard() }` plus `.onChange(of: vm.cards) { _ in publishActiveCard() }` on the same view that owns `selectedCard`. (Match the existing onChange signature style in the file; `Card` is `Equatable` so `vm.cards` onChange compiles.)

- [ ] **Step 2: Clear on sign-out.** In `AuthViewModel.signOut()`, after `userId = nil`, add `AtollAppGroup.save(nil)` and `import WidgetKit` + `WidgetCenter.shared.reloadAllTimelines()`. (AuthViewModel is in the app target; `AtollAppGroup` is shared and visible.)

- [ ] **Step 3: Build + tests green**
Run: `xcodegen generate && xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' 2>&1 | grep -iE "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" | tail -2` ; macOS build green.
Expected: all tests pass (33: prior 30 + 3 new from Task 1).

- [ ] **Step 4: Commit**
```bash
git add AtollCard/Features/Shell/RootTabView.swift AtollCard/Features/Auth/AuthViewModel.swift
git commit -m "feat(ios): publish active card to app group + reload widget

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Verifikationsgate

**Files:** keine.

- [ ] **Step 1: Builds + tests grün** — App+Widget (iOS) build, macOS app build, iOS test suite.
- [ ] **Step 2: Snapshot-E2E (Controller).** Kurzer Swift-/Test-Lauf bzw. der `AtollAppGroupTests` belegt save→load; zusätzlich Bestätigung, dass `publishActiveCard` an den richtigen Stellen aufgerufen wird (Code-Review der RootTabView-Hooks).
- [ ] **Step 3: Notiz:** Widget visuell auf dem Home-Screen (Sim-Widget hinzufügen) ist interaktiv → Vera/Nutzer. App-Group auf echtem Gerät braucht Portal-Registrierung der Group-ID `group.com.weckherlin.atollcard` (analog SIWA). Dokumentieren.

---

## Self-Review
- **Spec-Abdeckung:** Shared Snapshot + AppGroup + Color-Extraktion (T1), Widget-Target+Entitlements+UI small/medium+Platzhalter (T2), App-Schreib-Trigger + Sign-out-Clear + Reload (T3), Gate (T4). ✓
- **Platzhalter:** keine; voller Code für Snapshot/AppGroup/Widget/Tests + exakte project.yml/entitlement-Schnipsel. ✓
- **Typkonsistenz:** `SharedCardSnapshot(slug:displayName:accentColor:)` identisch in T1 (Def/Tests), T2 (Provider/Views), T3 (publish). `AtollAppGroup.save(_:suiteName:)`/`load(suiteName:)` mit Default-Suite in T1, ohne Suite-Arg in T2/T3 genutzt (Default greift). `QRCodeGenerator.image(for:)`/`profileURL(forSlug:)` (bestehend) in T2. App-Group-ID `group.com.weckherlin.atollcard` identisch in beiden Entitlements + `AtollAppGroup.suiteName`. ✓
- **Risiko:** xcodegen `embed: true` für App-Extension — falls die Syntax abweicht, Implementer meldet; Fallback: `dependencies: - target: AtollCardWidget` (xcodegen embedded App-Extensions automatisch in die App).
