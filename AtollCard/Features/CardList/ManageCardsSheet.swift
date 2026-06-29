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
    @State private var pendingDeletion: Card?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.cards) { card in
                        Button {
                            selectedCardId = card.id
                            dismiss()
                        } label: {
                            row(for: card)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = card
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDeletion = card
                            } label: {
                                Label("Karte löschen", systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
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
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .background(Theme.appBG.ignoresSafeArea())
            .confirmationDialog(
                "Diese Karte löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { card in
                Button("Löschen", role: .destructive) {
                    Task { await delete(card) }
                }
                Button("Abbrechen", role: .cancel) { pendingDeletion = nil }
            } message: { card in
                Text("\(card.label) wird dauerhaft entfernt. Dies kann nicht rückgängig gemacht werden.")
            }
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

    /// Deletes a card via the view model and keeps the active selection consistent:
    /// if the deleted card was the active one, fall back to the first remaining card (or nil).
    private func delete(_ card: Card) async {
        let wasSelected = selectedCardId == card.id
        await vm.delete(card.id)
        pendingDeletion = nil
        if wasSelected {
            selectedCardId = vm.cards.first?.id
        }
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
