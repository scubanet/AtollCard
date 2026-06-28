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
}
