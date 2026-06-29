import SwiftUI

/// Reusable glass card treatment matching the AtollCard mockup:
/// `.ultraThinMaterial` fill clipped to a rounded rect, a hairline white
/// border, and a soft shadow. Cross-platform (no UIKit/AppKit-only types).
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 20, x: 0, y: 8)
    }

    @ViewBuilder private var glassFill: some View {
        if reduceTransparency { Theme.surface } else { Color.clear.background(.ultraThinMaterial) }
    }
}

extension View {
    /// Applies the AtollCard glass-surface treatment.
    func glassSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
