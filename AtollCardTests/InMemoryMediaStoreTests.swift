import XCTest
@testable import AtollCard

final class InMemoryMediaStoreTests: XCTestCase {
    func test_uploadReturnsDeterministicPublicURL() async throws {
        let store = InMemoryMediaStore(publicBase: "https://x.supabase.co/storage/v1/object/public")
        let owner = UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000001")!
        let card = UUID(uuidString: "cccccccc-0000-0000-0000-000000000001")!
        let url = try await store.upload(Data([0x1]), owner: owner, card: card, kind: .cover)
        XCTAssertEqual(url.absoluteString,
          "https://x.supabase.co/storage/v1/object/public/card-media/aaaaaaaa-0000-0000-0000-000000000001/cccccccc-0000-0000-0000-000000000001/cover")
    }
}
