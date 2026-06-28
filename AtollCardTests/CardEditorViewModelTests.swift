import XCTest
@testable import AtollCard

@MainActor
final class CardEditorViewModelTests: XCTestCase {
    func test_saveNewCardPersists() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        let vm = CardEditorViewModel(store: store, ownerId: owner, editing: nil)
        vm.displayName = "Jane Doe"
        vm.slug = "jane-doe"
        vm.addField(type: .email, label: "Work", value: "jane@acme.com")
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let cards = try await store.cards(forOwner: owner)
        XCTAssertEqual(cards.first?.slug, "jane-doe")
        let fields = try await store.fields(forCard: cards.first!.id)
        XCTAssertEqual(fields.count, 1)
    }

    func test_saveFailsOnTakenSlug() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        try await store.create(Card(id: UUID(), ownerId: owner, slug: "taken", displayName: "X",
            title: nil, company: nil, theme: "default", logoURL: nil, photoURL: nil,
            visibility: .private, isActive: true), fields: [])
        let vm = CardEditorViewModel(store: store, ownerId: owner, editing: nil)
        vm.displayName = "Y"
        vm.slug = "taken"
        let ok = await vm.save()
        XCTAssertFalse(ok)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_saveFailsOnEmptyDisplayName() async {
        let vm = CardEditorViewModel(store: InMemoryCardStore(), ownerId: UUID(), editing: nil)
        vm.slug = "abc"
        let ok = await vm.save()
        XCTAssertFalse(ok)
    }
}
