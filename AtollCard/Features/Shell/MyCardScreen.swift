import SwiftUI

/// "Meine Karte" screen — matches `card.png`: header, "Karten" pill,
/// card-selector pills, and the dark teal glass business card.
struct MyCardScreen: View {
    let store: CardStoring
    let mediaStore: MediaStoring
    let ownerId: UUID
    @ObservedObject var vm: CardListViewModel
    @Binding var selectedCardId: UUID?

    @State private var fields: [CardField] = []
    @State private var presentedSheet: CardSheet?

    private var selectedCard: Card? {
        if let id = selectedCardId, let c = vm.cards.first(where: { $0.id == id }) { return c }
        return vm.cards.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !vm.cards.isEmpty {
                    cardSelector
                }

                if let card = selectedCard {
                    BusinessCardView(
                        card: card,
                        fields: fields,
                        onShare: { presentedSheet = .share(card) },
                        onEdit: { presentedSheet = .edit(card) }
                    )
                    .padding(.top, 4)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120) // clear the floating tab bar
        }
        .background(Theme.appBG.ignoresSafeArea())
        .task(id: selectedCard?.id) { await loadFields() }
        .sheet(item: $presentedSheet, onDismiss: {
            Task { await vm.load(); await loadFields() }
        }) { sheet in
            switch sheet {
            case .share(let card):
                ShareSheet(card: card, store: store)
            case .edit(let card):
                EditSheet(store: store, mediaStore: mediaStore, ownerId: ownerId, card: card)
            case .manage:
                ManageCardsSheet(store: store, mediaStore: mediaStore, ownerId: ownerId,
                                 vm: vm, selectedCardId: $selectedCardId)
            case .onboarding:
                OnboardingView(store: store, mediaStore: mediaStore, ownerId: ownerId)
            }
        }
    }

    private func loadFields() async {
        guard let id = selectedCard?.id else { fields = []; return }
        fields = (try? await store.fields(forCard: id)) ?? []
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Deine Visitenkarte")
                    .font(.atoll(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text2)
                Text("Meine Karte")
                    .font(.atoll(size: 30, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            Button {
                presentedSheet = .manage
            } label: {
                Label("Karten", systemImage: "rectangle.stack")
                    .font(.atoll(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 22)
            .accessibilityLabel("Karten verwalten")
        }
    }

    // MARK: - Card selector pills

    private var cardSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.cards) { card in
                    CardPill(
                        card: card,
                        isSelected: card.id == selectedCard?.id,
                        action: { selectedCardId = card.id }
                    )
                }
                Button {
                    presentedSheet = .onboarding
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().strokeBorder(
                                Theme.text2.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Neue Karte hinzufügen")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.text2)
            Text("Noch keine Karte")
                .font(.atoll(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Erstelle deine erste digitale Visitenkarte.")
                .font(.atoll(size: 15))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Button {
                presentedSheet = .onboarding
            } label: {
                Text("Karte erstellen")
                    .font(.atoll(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accentDefault, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// A selector pill for one card: glass capsule with a colored dot + label.
private struct CardPill: View {
    let card: Card
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSelected {
                    Text(card.label)
                        .font(.atoll(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Color(hex: card.accentColor))
                        .frame(width: 8, height: 8)
                    Text(card.label)
                        .font(.atoll(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(Theme.accentDefault)
                } else {
                    Capsule().fill(reduceTransparency ? AnyShapeStyle(Theme.surface) : AnyShapeStyle(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

enum CardSheet: Identifiable {
    case share(Card)
    case edit(Card)
    case manage
    case onboarding

    var id: String {
        switch self {
        case .share(let card): return "share-\(card.id)"
        case .edit(let card): return "edit-\(card.id)"
        case .manage: return "manage"
        case .onboarding: return "onboarding"
        }
    }
}

#Preview {
    MyCardScreen(
        store: AppStores.preview.cardStore,
        mediaStore: AppStores.preview.mediaStore,
        ownerId: UUID(),
        vm: CardListViewModel(store: AppStores.preview.cardStore, ownerId: UUID()),
        selectedCardId: .constant(nil)
    )
}
