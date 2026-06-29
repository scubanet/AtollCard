import XCTest
@testable import AtollCard

@MainActor
final class CardEditorViewModelTests: XCTestCase {
    func test_saveNewCardPersists() async throws {
        let store = InMemoryCardStore()
        let owner = UUID()
        let vm = CardEditorViewModel(store: store,
            mediaStore: InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public"),
            ownerId: owner, editing: nil)
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
        let vm = CardEditorViewModel(store: store,
            mediaStore: InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public"),
            ownerId: owner, editing: nil)
        vm.displayName = "Y"
        vm.slug = "taken"
        let ok = await vm.save()
        XCTAssertFalse(ok)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_saveFailsOnEmptyDisplayName() async {
        let vm = CardEditorViewModel(store: InMemoryCardStore(),
            mediaStore: InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public"),
            ownerId: UUID(), editing: nil)
        vm.slug = "abc"
        let ok = await vm.save()
        XCTAssertFalse(ok)
    }

    func test_uploadsPendingMediaAndSetsURLs() async throws {
        let store = InMemoryCardStore()
        let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let owner = UUID()
        let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: nil)
        vm.displayName = "Jane"; vm.slug = "jane"
        vm.pendingCoverData = Data([0x1]); vm.pendingPhotoData = Data([0x2])
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let card = try await store.cards(forOwner: owner).first!
        XCTAssertEqual(media.stored.count, 2)
        XCTAssertTrue(card.coverURL?.contains("/cover") == true)
        XCTAssertTrue(card.photoURL?.contains("/photo") == true)
    }

    func test_editPreservesExistingMediaURLs() async throws {
        let store = InMemoryCardStore()
        let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let owner = UUID()
        let existing = Card(id: UUID(), ownerId: owner, slug: "j", displayName: "J",
            title: nil, company: nil, theme: "default",
            coverURL: "https://x/cover.jpg", logoURL: nil, photoURL: "https://x/photo.jpg",
            visibility: .private, isActive: true)
        try await store.create(existing, fields: [])
        let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: existing)
        vm.displayName = "J2"
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let card = try await store.cards(forOwner: owner).first!
        XCTAssertEqual(card.coverURL, "https://x/cover.jpg")
        XCTAssertEqual(card.photoURL, "https://x/photo.jpg")
        XCTAssertEqual(media.stored.count, 0)
    }

    @MainActor
    func test_loadFetchesExistingFieldsAndSavePreservesThem() async throws {
        let store = InMemoryCardStore()
        let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let owner = UUID()
        let card = Card(id: UUID(), ownerId: owner, slug: "j", displayName: "J",
            title: nil, company: nil, theme: "default", logoURL: nil, photoURL: nil,
            visibility: .private, isActive: true)
        let field = CardField(id: UUID(), type: .email, label: "Work", value: "j@x.com", sortOrder: 0)
        try await store.create(card, fields: [field])

        let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: card)
        XCTAssertTrue(vm.fields.isEmpty, "fields are not loaded at init")
        await vm.load()
        XCTAssertEqual(vm.fields.map(\.value), ["j@x.com"], "load() must fetch existing fields")

        let ok = await vm.save()
        XCTAssertTrue(ok)
        let saved = try await store.fields(forCard: card.id)
        XCTAssertEqual(saved.map(\.value), ["j@x.com"], "save must preserve existing fields")
    }

    @MainActor
    func test_removeFieldDeletesIt() async {
        let store = InMemoryCardStore()
        let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: UUID(), editing: nil)
        vm.addField(type: .email, label: "Work", value: "a@x.com")
        vm.addField(type: .phone, label: "Mobil", value: "123")
        vm.removeFields(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.fields.map(\.value), ["123"])
    }

    @MainActor
    func test_editedFieldValuePersistsOnSave() async throws {
        let store = InMemoryCardStore()
        let media = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let owner = UUID()
        let vm = CardEditorViewModel(store: store, mediaStore: media, ownerId: owner, editing: nil)
        vm.displayName = "J"; vm.slug = "j"
        vm.addField(type: .email, label: "Work", value: "old@x.com")
        vm.fields[0].value = "new@x.com"           // direct binding edit
        let ok = await vm.save()
        XCTAssertTrue(ok)
        let cards = try await store.cards(forOwner: owner)
        let saved = try await store.fields(forCard: cards.first!.id)
        XCTAssertEqual(saved.map(\.value), ["new@x.com"])
    }
}
