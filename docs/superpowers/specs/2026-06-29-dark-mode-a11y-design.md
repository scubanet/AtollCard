# Dark Mode + A11y-Härtung — Design

**Datum:** 2026-06-29
**Status:** Entwurf zur Freigabe
**M2-Sub-Projekt 3.** Querschnitts-Polish: System-Dark-Mode + Accessibility-Härtung (Dynamic Type, Kontrast, Reduce Transparency/Motion). Sammelt die Vera-Funde aus M1 + M2-Sub-1/2 ein. Vor Store-Launch.

## Ziel
App folgt automatisch Hell/Dunkel des Systems; Texte skalieren mit Dynamic Type; `text2`-Kontrast erfüllt WCAG AA; Glas degradiert bei „Transparenz reduzieren". Minimal-invasiv über die Design-System-Tokens — keine Massen-Call-Site-Umbauten.

## Entscheidungen
- Dark Mode: **nur System folgen** (kein In-App-Umschalter).
- Farben: **dynamische Theme-Tokens im Code** (`Color(light:dark:)`), kein Asset-Katalog.

## A. Dynamische Theme-Tokens
`AtollCard/DesignSystem/Theme.swift`:
- Neuer cross-platform Helper:
```swift
extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #elseif os(macOS)
        self = Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}
```
- Tokens werden Light/Dark-Paare (Hex via bestehendem `Color(hex:)`):

| Token | Light | Dark |
|---|---|---|
| accentDefault | #0E7C86 | #16A8B4 |
| appBG | #EEEFF2 | #0E1116 |
| surface | #FFFFFF | #1C1E24 |
| surface2 | #F2F2F6 | #2A2D34 |
| text | #14161A | #F2F3F5 |
| text2 | #5E636B | #9AA0AA |
| separator | black@0.10 | white@0.14 |

- `Color(hex:)` bleibt. `BusinessCardView`s dunkle Teal-Karte bleibt bewusst in beiden Modi dunkel (eigene Farben, nicht aus appBG/surface).

## B. Dynamic Type
`AtollCard/DesignSystem/FontRegistration.swift`:
- `manrope`/`atoll` bekommen `relativeTo: Font.TextStyle = .body`:
```swift
static func manrope(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
    Font.custom(Theme.font, size: size, relativeTo: style).weight(weight)
}
static func atoll(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
    manrope(size: size, weight: weight, relativeTo: style)
}
```
Default `.body` lässt alle 54 bestehenden Calls automatisch skalieren (keine Signaturbrüche — neuer Param hat Default). Große Titel (Aufrufe mit size ≥ 24, z. B. SignInView „AtollCard", Onboarding-/Detail-Titel) bekommen explizit `relativeTo: .title2` für angemessenes Scaling-Verhältnis.

## C. Reduce Transparency / Motion
`AtollCard/DesignSystem/GlassBackground.swift`:
- `@Environment(\.accessibilityReduceTransparency) var reduceTransparency`; bei `true` statt `.ultraThinMaterial` ein solides `Theme.surface` (Border/Shadow bleiben). Deckt die zentralen Glas-Flächen.
- Eigenständige `Material`-Nutzungen außerhalb von `GlassBackground` (FloatingTabBar) ebenfalls auf denselben Reduce-Transparency-Fallback bringen.
- Reduce Motion: custom Animationen (`.snappy` Tab-Wechsel / Step-Übergänge) unter `@Environment(\.accessibilityReduceMotion)` gaten (bei true ohne Animation).

## D. Tests / Verifikation
- `AtollCardTests/ThemeColorTests.swift`: `Color(light:dark:)` resolved unter iOS-Trait `.dark` ≠ `.light` (via `UITraitCollection(userInterfaceStyle:)` + `UIColor(resolvedColor)`), für mind. ein Token. Sicherstellt, dass der Helper wirklich zwei Werte liefert.
- Bestehende 28 iOS-Tests + 29 Web bleiben grün; iOS+macOS Build grün.
- **Manuelles Gate (Controller):** Sim-Screenshots in Light + Dark (`xcrun simctl ui <udid> appearance dark/light`) und bei großer Dynamic Type (`xcrun simctl ui <udid> content_size accessibility-extra-large`) — SignIn + Karte + Kontakte; visuelle Bestätigung, dass nichts bricht/abschneidet.

## Bewusst nicht hier
In-App-Theme-Umschalter; Asset-Katalog-Migration; vollständiges WCAG-Audit aller Screens (Vera separat); High-Contrast-Sonderpalette; Web-Dark-Mode (separater Web-Task).
