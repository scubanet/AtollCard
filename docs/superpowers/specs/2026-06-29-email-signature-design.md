# E-Mail-Signatur-Generator — Design

**Datum:** 2026-06-29
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 5.** Erzeugt aus der aktiven Karte eine E-Mail-Signatur (HTML rich + Plain-Text-Fallback) zum Kopieren/Teilen. Self-contained, kein externes Cert/Gerät.

## Ziel
Karten-Owner generiert eine fertige E-Mail-Signatur aus seiner Karte: Name, Titel, Firma, Kontaktfelder (als `mailto:`/`tel:`/Links) und Profil-URL. Format: formatiertes HTML in die Zwischenablage (Formatierung bleibt beim Einfügen in Mail) + Plain-Text-Fallback. **Kein Foto.**

## Entscheidungen
- Format: **HTML rich + Plain-Text-Fallback**.
- **Kein** Profilfoto (keine Hotlink-Abhängigkeit).
- Einstieg: aus `ShareSheet` (Share-Hub der Karte).

## A. `EmailSignatureBuilder` (rein, testbar)
`AtollCard/Features/Share/EmailSignatureBuilder.swift`:
```swift
enum EmailSignatureBuilder {
    static func html(for card: Card, fields: [CardField]) -> String
    static func plainText(for card: Card, fields: [CardField]) -> String
}
```
- **html**: ein `<div>` mit inline-Styles (E-Mail-Clients ignorieren `<style>`/Klassen). Name fett in `card.accentColor`; darunter Titel + Firma (gedämpftes Grau); dann je `CardField` eine Zeile — `phone` → `<a href="tel:…">`, `email` → `<a href="mailto:…">`, `url` → `<a href="…">`, `social`/`address`/`custom` → Text (Label: Wert). Abschluss: Profil-Link `https://card.atoll-os.com/<slug>`. **Alle dynamischen Werte HTML-escaped** (`&`,`<`,`>`,`"`). Kein `<img>`.
- **plainText**: Zeilen — `displayName`; `title · company` (nur vorhandene); je Feld `Label: value`; Profil-URL.
- HTML-Escape-Helper privat im Builder.

## B. `EmailSignatureView` (iOS + macOS)
`AtollCard/Features/Share/EmailSignatureView.swift`:
- `init(card: Card, store: CardStoring)`; `@State fields: [CardField] = []`; `.task { fields = (try? await store.fields(forCard: card.id)) ?? [] }`.
- Zeigt eine Vorschau (gerenderte Textfassung der Signatur in Glas-Karte) und Aktionen:
  - **Kopieren** (HTML + Plain): unter `#if os(iOS)` `UIPasteboard.general.setItems([["public.html": html, "public.utf8-plain-text": plain]])`; `#elseif os(macOS)` `NSPasteboard.general` → `clearContents()` + `setString(html, forType: .html)` + `setString(plain, forType: .string)`. Kurze Bestätigung („Kopiert").
  - **Teilen**: `ShareLink(item: EmailSignatureBuilder.plainText(...))` (cross-platform).
- Glas-Stil + `Theme`/`Font.atoll`. Titel „E-Mail-Signatur".

## C. Wiring
- `ShareSheet` erhält `store: CardStoring` als Property (vom Aufrufer `MyCardScreen` durchgereicht — `MyCardScreen` hat den `store` bereits). Neue Zeile/`NavigationLink` „E-Mail-Signatur" → `EmailSignatureView(card:store:)`.
- `grep` alle `ShareSheet(` und passe Konstruktion + Previews an (`AppStores.preview.cardStore`).

## D. Tests
`AtollCardTests/EmailSignatureBuilderTests.swift`:
- `html` enthält `displayName`, `title`, `company`; für ein email-Feld `mailto:`, für ein phone-Feld `tel:`; den Profil-Link `card.atoll-os.com/<slug>`; **keinen** `<img`.
- HTML-Escaping: ein Feldwert mit `A & <B>` erscheint als `A &amp; &lt;B&gt;`, nicht roh.
- `plainText` enthält Name + Feldwerte + URL und **keine** `<`-Tags.
- iOS+macOS Build grün; bestehende 37 Tests grün.

## Bewusst nicht hier
Foto/Logo in der Signatur; mehrere Signatur-Vorlagen/Themes; serverseitige Hosted-Signatur-Seite; direkte Mail-App-Integration (nur Copy/Share); Web-Signaturgenerator.
