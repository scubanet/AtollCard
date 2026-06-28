import SwiftUI

enum Theme {
    static let accentDefault = Color(hex: "#0E7C86")
    static let appBG    = Color(hex: "#EEEFF2")
    static let surface  = Color(hex: "#FFFFFF")
    static let surface2 = Color(hex: "#F2F2F6")
    static let text     = Color(hex: "#14161A")
    static let text2    = Color(hex: "#8A8F98")
    static let separator = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.10)
    static let font = "Manrope"   // bundled variable font; fallback to system
}

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
