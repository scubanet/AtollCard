import Foundation

final class InMemoryConnectionStore: ConnectionStoring {
    private var seed: [Connection]
    init(seed: [Connection] = []) { self.seed = seed }
    func connections(forOwner ownerId: UUID) async throws -> [Connection] {
        seed.sorted { $0.createdAt > $1.createdAt }
    }
    func delete(_ connectionId: UUID) async throws {
        seed.removeAll { $0.id == connectionId }
    }
}
