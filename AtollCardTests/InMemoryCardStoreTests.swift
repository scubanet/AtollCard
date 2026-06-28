import XCTest
@testable import AtollCard

final class InMemoryCardStoreTests: XCTestCase {
    func test_createThenListReturnsCard() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        let card = Card(id: UUID(), ownerId: owner, slug: "jane-doe",
                        displayName: "Jane Doe", title: nil, company: nil,
                        theme: "default", logoURL: nil, photoURL: nil,
                        visibility: .private, isActive: true)
        try await store.create(card, fields: [])
        let listed = try await store.cards(forOwner: owner)
        XCTAssertEqual(listed.map(\.slug), ["jane-doe"])
    }

    func test_updateReplacesFields() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        let card = Card(id: UUID(), ownerId: owner, slug: "j", displayName: "J",
                        title: nil, company: nil, theme: "default", logoURL: nil,
                        photoURL: nil, visibility: .private, isActive: true)
        try await store.create(card, fields: [])
        let field = CardField(id: UUID(), type: .email, label: "Work", value: "j@x.com", sortOrder: 0)
        try await store.update(card, fields: [field])
        let got = try await store.fields(forCard: card.id)
        XCTAssertEqual(got.map(\.value), ["j@x.com"])
    }
}
