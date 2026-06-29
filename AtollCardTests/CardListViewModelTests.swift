import XCTest
@testable import AtollCard

@MainActor
final class CardListViewModelTests: XCTestCase {
    func test_loadPopulatesCards() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        try await store.create(Card(id: UUID(), ownerId: owner, slug: "a", displayName: "A",
            title: nil, company: nil, theme: "default", logoURL: nil, photoURL: nil,
            visibility: .private, isActive: true), fields: [])
        let vm = CardListViewModel(store: store, ownerId: owner)
        await vm.load()
        XCTAssertEqual(vm.cards.count, 1)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func test_deleteRemovesCard() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        let a = Card(id: UUID(), ownerId: owner, slug: "a", displayName: "A",
            title: nil, company: nil, theme: "default", logoURL: nil, photoURL: nil,
            visibility: .private, isActive: true)
        let b = Card(id: UUID(), ownerId: owner, slug: "b", displayName: "B",
            title: nil, company: nil, theme: "default", logoURL: nil, photoURL: nil,
            visibility: .private, isActive: true)
        try await store.create(a, fields: [])
        try await store.create(b, fields: [])
        let vm = CardListViewModel(store: store, ownerId: owner)
        await vm.load()
        await vm.delete(a.id)
        XCTAssertEqual(vm.cards.map(\.slug), ["b"])
    }
}
