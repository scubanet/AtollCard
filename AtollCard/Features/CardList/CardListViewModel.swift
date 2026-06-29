import Foundation

@MainActor
final class CardListViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var errorMessage: String?

    private let store: CardStoring
    private let ownerId: UUID

    init(store: CardStoring, ownerId: UUID) {
        self.store = store
        self.ownerId = ownerId
    }

    func load() async {
        do {
            cards = try await store.cards(forOwner: ownerId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ cardId: UUID) async {
        do {
            try await store.delete(cardId)
            cards = try await store.cards(forOwner: ownerId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
