import SwiftUI

/// Lists all of the owner's cards (label + visibility + colored dot). Selecting
/// one makes it the active card and dismisses; a "+" entry opens onboarding.
struct ManageCardsSheet: View {
    let store: CardStoring
    let mediaStore: MediaStoring
    let ownerId: UUID
    @ObservedObject var vm: CardListViewModel
    @Binding var selectedCardId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.cards) { card in
                        Button {
                            selectedCardId = card.id
                            dismiss()
                        } label: {
                            row(for: card)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isPresentingOnboarding = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.accentDefault)
                            Text("Neue Karte erstellen")
                                .font(.atoll(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .glassSurface(cornerRadius: 18)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Theme.appBG.ignoresSafeArea())
            .navigationTitle("Karten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { await vm.load() }
            .sheet(isPresented: $isPresentingOnboarding, onDismiss: {
                Task { await vm.load() }
            }) {
                OnboardingView(store: store, mediaStore: mediaStore, ownerId: ownerId)
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private func row(for card: Card) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: card.accentColor))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.label)
                    .font(.atoll(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(card.displayName)
                    .font(.atoll(size: 13))
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            Text(visibilityLabel(card.visibility))
                .font(.atoll(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.surface2, in: Capsule())
            if card.id == selectedCardId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accentDefault)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassSurface(cornerRadius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.label), \(card.displayName), \(visibilityLabel(card.visibility))")
        .accessibilityAddTraits(card.id == selectedCardId ? [.isSelected, .isButton] : .isButton)
    }

    private func visibilityLabel(_ v: CardVisibility) -> String {
        switch v {
        case .public: return "Öffentlich"
        case .unlisted: return "Nicht gelistet"
        case .private: return "Privat"
        }
    }
}

#Preview {
    ManageCardsSheet(
        store: AppStores.preview.cardStore,
        mediaStore: AppStores.preview.mediaStore,
        ownerId: UUID(),
        vm: CardListViewModel(store: AppStores.preview.cardStore, ownerId: UUID()),
        selectedCardId: .constant(nil)
    )
}
