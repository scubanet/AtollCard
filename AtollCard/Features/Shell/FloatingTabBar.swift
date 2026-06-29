import SwiftUI

#if os(iOS)
/// Floating glass tab bar matching `floating-tabbar.png`: a rounded
/// `.ultraThinMaterial` capsule hovering above the bottom safe area with
/// three icon+label items. The active item is tinted with the accent color.
struct FloatingTabBar: View {
    @Binding var selection: ShellTab
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let items: [(tab: ShellTab, icon: String, label: String)] = [
        (.card, "person.text.rectangle.fill", "Karte"),
        (.contacts, "person.2.fill", "Kontakte"),
        (.settings, "sun.max.fill", "Einstellungen"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                Button {
                    if reduceMotion { selection = item.tab }
                    else { withAnimation(.snappy(duration: 0.2)) { selection = item.tab } }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(item.label)
                            .font(.atoll(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selection == item.tab ? Theme.accentDefault : Theme.text2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(selection == item.tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(reduceTransparency ? AnyShapeStyle(Theme.surface) : AnyShapeStyle(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 10)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Theme.appBG.ignoresSafeArea()
        FloatingTabBar(selection: .constant(.card))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }
}
#endif
