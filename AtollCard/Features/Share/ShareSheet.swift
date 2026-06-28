import CoreImage
import SwiftUI

/// Share sheet matching `share.png`: large QR code, the profile URL, a native
/// share button, and Wallet/NFC/Widget option rows (placeholders for M2).
struct ShareSheet: View {
    let slug: String
    @Environment(\.dismiss) private var dismiss
    @State private var showComingSoon = false

    private var url: URL { QRCodeGenerator.profileURL(forSlug: slug) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    qrImage
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .padding(20)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Theme.separator, lineWidth: 1)
                        )
                        .accessibilityLabel("QR-Code für dein AtollCard-Profil")

                    Text(url.absoluteString)
                        .font(.atoll(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text2)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)

                    ShareLink(item: url) {
                        Label("Profil teilen", systemImage: "square.and.arrow.up")
                            .font(.atoll(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accentDefault, in: Capsule())
                    }
                    .accessibilityLabel("Profil teilen")

                    VStack(spacing: 0) {
                        OptionRow(icon: "wallet.pass", title: "Zu Wallet hinzufügen") { showComingSoon = true }
                        OptionRow(icon: "wave.3.right", title: "Per NFC teilen") { showComingSoon = true }
                        OptionRow(icon: "square.text.square", title: "Als Widget anzeigen") { showComingSoon = true }
                    }
                    .glassSurface(cornerRadius: 18)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.appBG.ignoresSafeArea())
            .navigationTitle("Teilen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Bald verfügbar", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Diese Funktion kommt in einem späteren Update.")
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private var qrImage: Image {
        if let ci = QRCodeGenerator.image(for: url),
           let cgImage = CIContext().createCGImage(ci, from: ci.extent) {
            return Image(decorative: cgImage, scale: 1)
        }
        return Image(systemName: "qrcode")
    }
}

private struct OptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accentDefault)
                    .frame(width: 30)
                Text(title)
                    .font(.atoll(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("Bald")
                    .font(.atoll(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.surface2, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShareSheet(slug: "dominik-weckherlin")
}
