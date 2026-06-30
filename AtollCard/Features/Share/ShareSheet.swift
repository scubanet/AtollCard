import CoreImage
import SwiftUI
#if os(iOS)
import PassKit
#endif

/// Share sheet matching `share.png`: large QR code, the profile URL, a native
/// share button, and Wallet/NFC/Widget option rows (placeholders for M2).
struct ShareSheet: View {
    let card: Card
    let store: CardStoring
    var walletService: WalletPassProviding = SupabaseWalletService()
    @Environment(\.dismiss) private var dismiss
    @State private var showComingSoon = false
    #if os(iOS)
    @State private var walletPass: Data?
    @State private var walletError: String?
    @State private var isLoadingWallet = false
    #endif

    private var url: URL { QRCodeGenerator.profileURL(forSlug: card.slug) }

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
                        NavigationLink {
                            EmailSignatureView(card: card, store: store)
                        } label: {
                            NavRowLabel(icon: "envelope", title: "E-Mail-Signatur")
                        }
                        .buttonStyle(.plain)

                        #if os(iOS)
                        if PKPassLibrary.isPassLibraryAvailable() {
                            ActionRow(
                                icon: "wallet.pass",
                                title: "Zu Wallet hinzufügen",
                                isLoading: isLoadingWallet
                            ) { Task { await loadWallet() } }
                        }
                        #endif
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
            #if os(iOS)
            .sheet(isPresented: Binding(
                get: { walletPass != nil },
                set: { if !$0 { walletPass = nil } }
            )) {
                if let data = walletPass {
                    AddPassView(passData: data) { walletPass = nil }
                        .ignoresSafeArea()
                }
            }
            .alert(
                "Wallet-Pass fehlgeschlagen",
                isPresented: Binding(
                    get: { walletError != nil },
                    set: { if !$0 { walletError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(walletError ?? "")
            }
            #endif
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

    #if os(iOS)
    private func loadWallet() async {
        guard !isLoadingWallet else { return }
        isLoadingWallet = true
        defer { isLoadingWallet = false }
        do { walletPass = try await walletService.passData(forCardId: card.id) }
        catch { walletError = error.localizedDescription }
    }
    #endif
}

#if os(iOS)
private struct ActionRow: View {
    let icon: String
    let title: String
    let isLoading: Bool
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
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
#endif

private struct NavRowLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accentDefault)
                .frame(width: 30)
            Text(title)
                .font(.atoll(size: 16, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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
    ShareSheet(
        card: Card(
            id: UUID(), ownerId: UUID(), slug: "dominik-weckherlin",
            label: "Arbeit", displayName: "Dominik Weckherlin",
            title: "PADI Course Director", company: "Deep Blue Diving",
            theme: "default", accentColor: "#0E7C86",
            visibility: .public, isActive: true
        ),
        store: AppStores.preview.cardStore
    )
}
