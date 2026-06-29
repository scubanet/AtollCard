import XCTest
@testable import AtollCard

final class InMemoryConnectionStoreTests: XCTestCase {
    func test_listsSeededConnectionsNewestFirst() async throws {
        let owner = UUID()
        let older = Connection(id: UUID(), cardId: UUID(), name: "A", email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date(timeIntervalSince1970: 100))
        let newer = Connection(id: UUID(), cardId: UUID(), name: "B", email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date(timeIntervalSince1970: 200))
        let store = InMemoryConnectionStore(seed: [older, newer])
        let list = try await store.connections(forOwner: owner)
        XCTAssertEqual(list.map(\.name), ["B", "A"])
    }
}
