# Link-Sicherheit (Scheme-Allowlist) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nutzergelieferte `url`/`social`-Feldwerte nur als Link rendern, wenn das Scheme http/https ist — verhindert `javascript:`-stored-XSS auf dem öffentlichen Web-Profil; gleiche Härtung in der iOS-E-Mail-Signatur + tel-Normalisierung.

**Architecture:** Rendering-seitige Scheme-Allowlist an den zwei Stellen, die Roh-Feldwerte in `href` setzen: Web `fieldRow` (reuse `safeURL`) und iOS `EmailSignatureBuilder` (neuer `safeHref`). Unsicheres Scheme → Plain-Text statt Link.

**Tech Stack:** Vite+TS+vitest (Web), SwiftUI+XCTest (iOS), XcodeGen.

**Konventionen:** Web `cd web && npm test`. iOS `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`; macOS `-destination 'platform=macOS,arch=arm64'`. Nach iOS-Änderungen `xcodegen generate`. Commits enden mit `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure
- `web/src/render.ts` — `fieldRow()` Scheme-Allowlist.
- `web/tests/render.test.ts` — fieldRow-Sicherheitstests.
- `AtollCard/Features/Share/EmailSignatureBuilder.swift` — `safeHref` + tel-Normalisierung.
- `AtollCardTests/EmailSignatureBuilderTests.swift` — Sicherheitstests + tel-Update.

---

## Task 1: Web `fieldRow` Scheme-Allowlist

**Files:** Modify `web/src/render.ts`; Test `web/tests/render.test.ts`.

- [ ] **Step 1: Failing tests** — append to `web/tests/render.test.ts` (uses the exported `renderCard`):
```ts
import { describe, it, expect } from 'vitest'
import { renderCard } from '../src/render'

function cardWith(fields: { type: string; label: string; value: string }[]) {
  return {
    display_name: 'Jane', title: null, company: null, theme: 'default',
    accent_color: '#0E7C86', cover_url: null, logo_url: null, photo_url: null,
    fields,
  } as any
}

describe('fieldRow link safety', () => {
  it('does not emit a javascript: href for a url field', () => {
    const html = renderCard(cardWith([{ type: 'url', label: 'Web', value: 'javascript:alert(1)' }]))
    expect(html).not.toContain('href="javascript')
    expect(html).toContain('javascript:alert(1)') // shown as escaped text, not a link
    expect(html).toContain('<span class="value">javascript:alert(1)</span>')
  })
  it('emits an https href for a valid url field', () => {
    const html = renderCard(cardWith([{ type: 'url', label: 'Web', value: 'https://acme.example' }]))
    expect(html).toContain('href="https://acme.example')
  })
  it('treats social the same (no unsafe scheme)', () => {
    const html = renderCard(cardWith([{ type: 'social', label: 'X', value: 'data:text/html,evil' }]))
    expect(html).not.toContain('href="data:')
  })
  it('builds mailto/tel for email/phone', () => {
    const html = renderCard(cardWith([
      { type: 'email', label: 'M', value: 'a@b.co' },
      { type: 'phone', label: 'P', value: '+41 79 1' },
    ]))
    expect(html).toContain('href="mailto:a@b.co')
    expect(html).toContain('href="tel:+41791"') // whitespace stripped
  })
})
```

- [ ] **Step 2: Run → FAIL.** `cd web && npx vitest run render`.

- [ ] **Step 3: Implement** — replace `fieldRow` in `web/src/render.ts` with:
```ts
function fieldRow(f: PublicField): string {
  const label = escapeHTML(f.label)
  const value = escapeHTML(f.value)
  let href: string | null = null
  if (f.type === 'email') href = `mailto:${f.value.trim()}`
  else if (f.type === 'phone') href = `tel:${f.value.replace(/\s+/g, '')}`
  else if (f.type === 'url' || f.type === 'social') href = safeURL(f.value)
  const inner = href
    ? `<a class="value" href="${escapeHTML(href)}">${value}</a>`
    : `<span class="value">${value}</span>`
  return `<li class="field field--${f.type}"><span class="label">${label}</span>${inner}</li>`
}
```
(`safeURL` already returns only http/https or null. `email`/`phone` use fixed schemes; `escapeHTML(href)` keeps the attribute safe. `custom`/`address` fall through to the non-link `<span>`.)

- [ ] **Step 4: Run → PASS.** `cd web && npm test` (new + existing 29 green).

- [ ] **Step 5: Commit**
```bash
git add web/src/render.ts web/tests/render.test.ts
git commit -m "fix(web): scheme-allowlist field links (prevent javascript: XSS)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: iOS `EmailSignatureBuilder` safe href + tel normalization

**Files:** Modify `AtollCard/Features/Share/EmailSignatureBuilder.swift`; Test `AtollCardTests/EmailSignatureBuilderTests.swift`.

- [ ] **Step 1: Failing tests** — append to `AtollCardTests/EmailSignatureBuilderTests.swift`:
```swift
func test_htmlRejectsUnsafeUrlScheme() {
    let f = [CardField(id: UUID(), type: .url, label: "Web", value: "javascript:alert(1)", sortOrder: 0)]
    let html = EmailSignatureBuilder.html(for: card(), fields: f)
    XCTAssertFalse(html.contains("href=\"javascript"))
    XCTAssertTrue(html.contains("javascript:alert(1)"))   // shown as escaped text
}
func test_htmlKeepsHttpsUrl() {
    let f = [CardField(id: UUID(), type: .url, label: "Web", value: "https://acme.example", sortOrder: 0)]
    let html = EmailSignatureBuilder.html(for: card(), fields: f)
    XCTAssertTrue(html.contains("href=\"https://acme.example"))
}
func test_htmlNormalizesTelWhitespace() {
    let f = [CardField(id: UUID(), type: .phone, label: "P", value: "+41 79 123", sortOrder: 0)]
    let html = EmailSignatureBuilder.html(for: card(), fields: f)
    XCTAssertTrue(html.contains("href=\"tel:+4179123\""))   // no spaces in href
    XCTAssertTrue(html.contains("+41 79 123"))              // display keeps spaces
}
```
ALSO update the existing `test_htmlContainsCoreContent`: change `XCTAssertTrue(html.contains("tel:+41 79"))` to `XCTAssertTrue(html.contains("tel:+4179"))` (the phone field value "+41 79" normalizes to a space-free tel href; display text "+41 79" stays).

- [ ] **Step 2: Run → FAIL.**
Run: `xcodebuild test -scheme AtollCard -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:AtollCardTests/EmailSignatureBuilderTests 2>&1 | grep -iE "error:|Executed|TEST (SUCCEEDED|FAILED)"`

- [ ] **Step 3: Implement** — in `EmailSignatureBuilder`, replace the per-field `switch` so href comes from raw value with allowlist + tel normalization, and add the `safeHref` helper. The relevant region becomes:
```swift
        for f in fields {
            let label = esc(f.label)
            let display = esc(f.value)
            let content: String
            switch f.type {
            case .phone:
                let tel = f.value.filter { !$0.isWhitespace }
                content = "<a href=\"tel:\(esc(tel))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
            case .email:
                content = "<a href=\"mailto:\(esc(f.value))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
            case .url:
                if let href = safeHref(f.value) {
                    content = "<a href=\"\(esc(href))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
                } else {
                    content = display
                }
            case .social, .address, .custom:
                content = display
            }
            rows += "<div style=\"font-size:13px;color:#555555;margin-top:2px\">\(label): \(content)</div>"
        }
```
And add, next to `esc`:
```swift
    private static func safeHref(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = t.lowercased()
        return (l.hasPrefix("http://") || l.hasPrefix("https://")) ? t : nil
    }
```
(Builder already escapes via `esc`; `esc(href)` keeps the attribute safe. The plain-text fallback path uses `display`, which is already escaped.)

- [ ] **Step 4: Run → PASS.** Full iOS suite (`-only-testing` removed) + macOS build green.

- [ ] **Step 5: Commit**
```bash
cd /Users/dominik/Developer/AtollCard
git add AtollCard/Features/Share/EmailSignatureBuilder.swift AtollCardTests/EmailSignatureBuilderTests.swift
git commit -m "fix(ios): scheme-allowlist signature url href + normalize tel whitespace

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review
- **Spec-Abdeckung:** Web fieldRow Allowlist (T1, url/social→safeURL, email/phone fixed, plain-text-fallback), iOS Builder safeHref + tel-Normalisierung (T2). iOS-Karten/Detail nicht betroffen (Spec geprüft). ✓
- **Platzhalter:** keine; voller Code für fieldRow + Builder-Switch + Tests. ✓
- **Typkonsistenz:** Web `safeURL(raw)->string|null` (bestehend) in fieldRow; iOS `safeHref(String)->String?` neu, nur im Builder genutzt; `esc` (bestehend). Bestehender tel-Test wird mit-aktualisiert (sonst Rotbruch). ✓
