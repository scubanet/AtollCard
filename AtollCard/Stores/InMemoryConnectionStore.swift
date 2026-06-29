import Foundation

final class InMemoryConnectionStore: ConnectionStoring {
    private let seed: [Connection]
    init(seed: [Connection] = []) { self.seed = seed }
    func connections(forOwner ownerId: UUID) async throws -> [Connection] {
        seed.sorted { $0.createdAt > $1.createdAt }
    }
}
