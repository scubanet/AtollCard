import Foundation

@MainActor
final class ConnectionsViewModel: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var errorMessage: String?

    private let store: ConnectionStoring
    private let ownerId: UUID

    init(store: ConnectionStoring, ownerId: UUID) {
        self.store = store
        self.ownerId = ownerId
    }

    func load() async {
        do {
            connections = try await store.connections(forOwner: ownerId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
