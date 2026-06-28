import Foundation

final class InMemoryCardStore: CardStoring {
    private var cardsById: [UUID: Card] = [:]
    private var fieldsByCard: [UUID: [CardField]] = [:]

    func cards(forOwner ownerId: UUID) async throws -> [Card] {
        cardsById.values.filter { $0.ownerId == ownerId }.sorted { $0.slug < $1.slug }
    }
    func fields(forCard cardId: UUID) async throws -> [CardField] {
        (fieldsByCard[cardId] ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
    func create(_ card: Card, fields: [CardField]) async throws {
        guard try await slugIsAvailable(card.slug) else {
            throw NSError(domain: "AtollCard", code: 23505, userInfo: [NSLocalizedDescriptionKey: "slug taken"])
        }
        cardsById[card.id] = card
        fieldsByCard[card.id] = fields
    }
    func update(_ card: Card, fields: [CardField]) async throws {
        cardsById[card.id] = card
        fieldsByCard[card.id] = fields
    }
    func delete(_ cardId: UUID) async throws {
        cardsById[cardId] = nil
        fieldsByCard[cardId] = nil
    }
    func slugIsAvailable(_ slug: String) async throws -> Bool {
        !cardsById.values.contains { $0.slug == slug }
    }
}
