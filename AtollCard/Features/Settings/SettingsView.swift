import SwiftUI

/// Presentational settings: sharing + appearance rows (no real logic in M1)
/// plus a working sign-out action.
struct SettingsView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var showComingSoon = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                section(title: "Teilen") {
                    SettingsRow(icon: "wallet.pass", title: "Zu Wallet hinzufügen",
                                subtitle: "Bald verfügbar") { showComingSoon = true }
                    SettingsRow(icon: "wave.3.right", title: "NFC-Tag schreiben",
                                subtitle: "Bald verfügbar") { showComingSoon = true }
                    SettingsRow(icon: "square.text.square", title: "Widget einrichten",
                                subtitle: "Bald verfügbar") { showComingSoon = true }
                }

                section(title: "Darstellung") {
                    SettingsRow(icon: "sun.max", title: "Erscheinungsbild",
                                subtitle: "System") { showComingSoon = true }
                    SettingsRow(icon: "textformat.size", title: "Schriftgröße",
                                subtitle: "Standard") { showComingSoon = true }
                }

                section(title: "Konto") {
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right",
                                title: "Abmelden", subtitle: nil, isDestructive: true) {
                        Task { await authVM.signOut() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Theme.appBG.ignoresSafeArea())
        .alert("Bald verfügbar", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Diese Funktion kommt in einem späteren Update.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Konfiguration")
                .font(.atoll(size: 14, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text("Einstellungen")
                .font(.atoll(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section<Content: View>(title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.atoll(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.text2)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .glassSurface(cornerRadius: 18)
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isDestructive ? Color.red : Theme.accentDefault)
                    .frame(width: 30)
                Text(title)
                    .font(.atoll(size: 16, weight: .medium))
                    .foregroundStyle(isDestructive ? Color.red : Theme.text)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.atoll(size: 14))
                        .foregroundStyle(Theme.text2)
                }
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text2.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(authVM: AuthViewModel(authenticator: AppStores.preview.authenticator))
}
