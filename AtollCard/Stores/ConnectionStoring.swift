import Foundation

protocol ConnectionStoring {
    func connections(forOwner ownerId: UUID) async throws -> [Connection]
    func delete(_ connectionId: UUID) async throws
}
