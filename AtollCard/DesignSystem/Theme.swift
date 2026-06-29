import SwiftUI

enum Theme {
    static let accentDefault = Color(light: Color(hex: "#0E7C86"), dark: Color(hex: "#16A8B4"))
    static let appBG    = Color(light: Color(hex: "#EEEFF2"), dark: Color(hex: "#0E1116"))
    static let surface  = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1C1E24"))
    static let surface2 = Color(light: Color(hex: "#F2F2F6"), dark: Color(hex: "#2A2D34"))
    static let text     = Color(light: Color(hex: "#14161A"), dark: Color(hex: "#F2F3F5"))
    static let text2    = Color(light: Color(hex: "#5E636B"), dark: Color(hex: "#9AA0AA"))
    static let separator = Color(light: Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.10),
                                 dark: Color.white.opacity(0.14))
    static let font = "Manrope"
}

extension Color {
    /// Resolves to `light` or `dark` based on the active interface style.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #elseif canImport(AppKit)
        self = Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}
