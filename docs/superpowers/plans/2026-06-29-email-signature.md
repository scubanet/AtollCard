# E-Mail-Signatur-Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aus der aktiven Karte eine E-Mail-Signatur erzeugen (HTML rich + Plain-Text-Fallback), kopier-/teilbar aus dem ShareSheet.

**Architecture:** Reiner `EmailSignatureBuilder` (Card + [CardField] → HTML/Plain) + `EmailSignatureView` (lädt Felder, kopiert HTML+Plain in die Zwischenablage, teilt Plain). Einstieg aus `ShareSheet`.

**Tech Stack:** SwiftUI, UIKit/AppKit (Pasteboard), XCTest, XcodeGen, Swift 5.

**Konventionen:** Repo `~/Developer/AtollCard`. Nach neuen Dateien `xcodegen generate`. iOS-Test `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' [-only-testing:...]`; macOS `-destination 'platform=macOS,arch=arm64'`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `AtollCard/Features/Share/EmailSignatureBuilder.swift` — reiner HTML/Plain-Generator.
- `AtollCard/Features/Share/EmailSignatureView.swift` — Vorschau + Kopieren/Teilen.
- `AtollCard/Features/Share/ShareSheet.swift` — `store` + Zeile zur Signatur.
- `AtollCard/Features/Shell/MyCardScreen.swift` — `store` an ShareSheet durchreichen (falls nötig).
- Test: `AtollCardTests/EmailSignatureBuilderTests.swift`.

---

## Task 1: `EmailSignatureBuilder`

**Files:** Create `AtollCard/Features/Share/EmailSignatureBuilder.swift`; Test `AtollCardTests/EmailSignatureBuilderTests.swift`.

- [ ] **Step 1: Failing test** `AtollCardTests/EmailSignatureBuilderTests.swift`
```swift
import XCTest
@testable import AtollCard

final class EmailSignatureBuilderTests: XCTestCase {
    private func card(slug: String = "jane-doe") -> Card {
        Card(id: UUID(), ownerId: UUID(), slug: slug, displayName: "Jane Doe",
             title: "CTO", company: "Acme", theme: "default", accentColor: "#0E7C86",
             coverURL: nil, logoURL: nil, photoURL: nil, visibility: .public, isActive: true)
    }
    private let fields = [
        CardField(id: UUID(), type: .email, label: "Work", value: "jane@acme.com", sortOrder: 0),
        CardField(id: UUID(), type: .phone, label: "Mobil", value: "+41 79", sortOrder: 1),
    ]

    func test_htmlContainsCoreContent() {
        let html = EmailSignatureBuilder.html(for: card(), fields: fields)
        XCTAssertTrue(html.contains("Jane Doe"))
        XCTAssertTrue(html.contains("CTO"))
        XCTAssertTrue(html.contains("Acme"))
        XCTAssertTrue(html.contains("mailto:jane@acme.com"))
        XCTAssertTrue(html.contains("tel:+41 79"))
        XCTAssertTrue(html.contains("card.atoll-os.com/jane-doe"))
        XCTAssertFalse(html.contains("<img"), "no photo in signature")
    }

    func test_htmlEscapesValues() {
        let f = [CardField(id: UUID(), type: .custom, label: "X", value: "A & <B>", sortOrder: 0)]
        let html = EmailSignatureBuilder.html(for: card(), fields: f)
        XCTAssertTrue(html.contains("A &amp; &lt;B&gt;"))
        XCTAssertFalse(html.contains("A & <B>"))
    }

    func test_plainTextHasNoTags() {
        let plain = EmailSignatureBuilder.plainText(for: card(), fields: fields)
        XCTAssertTrue(plain.contains("Jane Doe"))
        XCTAssertTrue(plain.contains("jane@acme.com"))
        XCTAssertTrue(plain.contains("https://card.atoll-os.com/jane-doe"))
        XCTAssertFalse(plain.contains("<"))
    }
}
```

- [ ] **Step 2: Run → FAIL** (`EmailSignatureBuilder` missing).
Run: `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:AtollCardTests/EmailSignatureBuilderTests 2>&1 | grep -iE "error:|Executed|TEST (SUCCEEDED|FAILED)"`

- [ ] **Step 3: Implement** `AtollCard/Features/Share/EmailSignatureBuilder.swift`
```swift
import Foundation

enum EmailSignatureBuilder {
    static func html(for card: Card, fields: [CardField]) -> String {
        let accent = esc(card.accentColor)
        let titleCompany = [card.title, card.company]
            .compactMap { $0 }.filter { !$0.isEmpty }.map(esc).joined(separator: " · ")
        var rows = ""
        for f in fields {
            let label = esc(f.label)
            let value = esc(f.value)
            let content: String
            switch f.type {
            case .phone: content = "<a href=\"tel:\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .email: content = "<a href=\"mailto:\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .url:   content = "<a href=\"\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .social, .address, .custom: content = value
            }
            rows += "<div style=\"font-size:13px;color:#555555;margin-top:2px\">\(label): \(content)</div>"
        }
        let profile = "https://card.atoll-os.com/\(esc(card.slug))"
        let tcLine = titleCompany.isEmpty ? "" : "<div style=\"font-size:13px;color:#888888\">\(titleCompany)</div>"
        return """
        <div style="font-family:-apple-system,Segoe UI,Arial,sans-serif">
        <div style="font-size:16px;font-weight:700;color:\(accent)">\(esc(card.displayName))</div>
        \(tcLine)
        \(rows)
        <div style="font-size:13px;margin-top:4px"><a href="\(profile)" style="color:\(accent);text-decoration:none">card.atoll-os.com/\(esc(card.slug))</a></div>
        </div>
        """
    }

    static func plainText(for card: Card, fields: [CardField]) -> String {
        var lines = [card.displayName]
        let tc = [card.title, card.company].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        if !tc.isEmpty { lines.append(tc) }
        for f in fields { lines.append("\(f.label): \(f.value)") }
        lines.append("https://card.atoll-os.com/\(card.slug)")
        return lines.joined(separator: "\n")
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
```
(Note: `&` is replaced first so later entities aren't double-escaped. The `card.atoll-os.com/jane-doe` test substring is satisfied by the visible link text.)

- [ ] **Step 4: Run → PASS** (3 tests).

- [ ] **Step 5: Commit**
```bash
git add AtollCard/Features/Share/EmailSignatureBuilder.swift AtollCardTests/EmailSignatureBuilderTests.swift
git commit -m "feat(ios): email signature builder (HTML + plain text)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `EmailSignatureView` + ShareSheet entry

**Files:** Create `AtollCard/Features/Share/EmailSignatureView.swift`; Modify `AtollCard/Features/Share/ShareSheet.swift`, `AtollCard/Features/Shell/MyCardScreen.swift`.

- [ ] **Step 1: View** `AtollCard/Features/Share/EmailSignatureView.swift`
```swift
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EmailSignatureView: View {
    let card: Card
    let store: CardStoring
    @State private var fields: [CardField] = []
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Vorschau")
                    .font(.atoll(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                Text(EmailSignatureBuilder.plainText(for: card, fields: fields))
                    .font(.atoll(size: 14))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassSurface(cornerRadius: 18)

                HStack(spacing: 12) {
                    Button { copy() } label: {
                        Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentDefault)

                    ShareLink(item: EmailSignatureBuilder.plainText(for: card, fields: fields)) {
                        Label("Teilen", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .background(Theme.appBG.ignoresSafeArea())
        #if os(iOS)
        .navigationTitle("E-Mail-Signatur")
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { fields = (try? await store.fields(forCard: card.id)) ?? [] }
    }

    private func copy() {
        let html = EmailSignatureBuilder.html(for: card, fields: fields)
        let plain = EmailSignatureBuilder.plainText(for: card, fields: fields)
        #if os(iOS)
        UIPasteboard.general.setItems([["public.html": html, "public.utf8-plain-text": plain]])
        #elseif os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .html)
        pb.setString(plain, forType: .string)
        #endif
        copied = true
    }
}
```

- [ ] **Step 2: ShareSheet entry.** Read `AtollCard/Features/Share/ShareSheet.swift`. Add a stored `let store: CardStoring`. Ensure the sheet content is inside a `NavigationStack` (add one if absent). Add a row/`NavigationLink` "E-Mail-Signatur" (icon `envelope`) → `EmailSignatureView(card: card, store: store)` (use the card the sheet already holds). Keep existing QR/link/Wallet-NFC-Widget rows. Match existing styling.

- [ ] **Step 3: Thread `store` into ShareSheet.** `grep -rn "ShareSheet(" AtollCard` — every construction (in `MyCardScreen` and previews) must pass `store:`. `MyCardScreen` already has a `store` (`CardStoring`); pass it. Previews use `AppStores.preview.cardStore`.

- [ ] **Step 4: Build both platforms + tests**
```
xcodegen generate
xcodebuild test  -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'
xcodebuild build -scheme AtollCard -destination 'platform=macOS,arch=arm64'
```
Erwartet: TEST SUCCEEDED (40: prior 37 + 3 from Task 1), beide BUILD SUCCEEDED.

- [ ] **Step 5: Commit**
```bash
git add AtollCard/Features/Share/EmailSignatureView.swift AtollCard/Features/Share/ShareSheet.swift AtollCard/Features/Shell/MyCardScreen.swift
git commit -m "feat(ios): email signature view + ShareSheet entry (copy HTML/plain, share)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review
- **Spec-Abdeckung:** Builder html/plain + Escaping + kein img (T1), View mit Vorschau/Kopieren(HTML+Plain)/Teilen + ShareSheet-Einstieg + store-Durchreichung (T2). ✓
- **Platzhalter:** keine; voller Code für Builder, Tests, View; ShareSheet-Edit beschrieben mit exakten Anforderungen (bestehende Datei, Implementer passt an). ✓
- **Typkonsistenz:** `EmailSignatureBuilder.html(for:fields:)`/`plainText(for:fields:)` identisch in T1 (Def/Tests) und T2 (View). `EmailSignatureView(card:store:)` in T2 + ShareSheet-Aufruf. `CardStoring.fields(forCard:)` (bestehend) in der View. Pasteboard-UTIs `public.html`/`public.utf8-plain-text` (iOS), `.html`/`.string` (macOS). ✓
