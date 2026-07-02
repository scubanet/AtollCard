import XCTest
@testable import AtollCard

@MainActor
final class ConnectionsViewModelTests: XCTestCase {
    func test_loadPopulates() async {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Max", firstName: nil, lastName: nil,
            email: "m@x.co", phone: nil, company: "Acme", note: nil, createdAt: Date())
        let vm = ConnectionsViewModel(store: InMemoryConnectionStore(seed: [c]), ownerId: UUID())
        await vm.load()
        XCTAssertEqual(vm.connections.count, 1)
        XCTAssertNil(vm.errorMessage)
    }

    func test_deleteRemovesConnection() async {
        let c = Connection(id: UUID(), cardId: UUID(), name: "X", firstName: nil, lastName: nil,
            email: nil, phone: nil, company: nil, note: nil, createdAt: Date())
        let store = InMemoryConnectionStore(seed: [c])
        let vm = ConnectionsViewModel(store: store, ownerId: UUID())
        await vm.load()
        await vm.delete(c.id)
        XCTAssertTrue(vm.connections.isEmpty)
    }
}
