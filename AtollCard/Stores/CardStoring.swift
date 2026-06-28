import Foundation

protocol CardStoring {
    func cards(forOwner ownerId: UUID) async throws -> [Card]
    func fields(forCard cardId: UUID) async throws -> [CardField]
    func create(_ card: Card, fields: [CardField]) async throws
    func update(_ card: Card, fields: [CardField]) async throws
    func delete(_ cardId: UUID) async throws
    func slugIsAvailable(_ slug: String) async throws -> Bool
}
