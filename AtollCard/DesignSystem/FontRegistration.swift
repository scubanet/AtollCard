import SwiftUI
import CoreText

enum AtollFonts {
    /// Registers all bundled `.ttf` fonts so `Font.custom(Theme.font, …)`
    /// resolves to Manrope. Safe to call once at app startup. Cross-platform.
    static func registerBundledFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
            return
        }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered fonts report a non-fatal error; ignore.
                error?.release()
            }
        }
    }
}

extension Font {
    /// Manrope at the given size/weight, falling back to the system font
    /// if the bundled family is unavailable.
    static func manrope(size: CGFloat, weight: Font.Weight = .regular,
                        relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(Theme.font, size: size, relativeTo: style).weight(weight)
    }

    /// Convenience alias matching the AtollCard naming.
    static func atoll(size: CGFloat, weight: Font.Weight = .regular,
                      relativeTo style: Font.TextStyle = .body) -> Font {
        manrope(size: size, weight: weight, relativeTo: style)
    }
}
