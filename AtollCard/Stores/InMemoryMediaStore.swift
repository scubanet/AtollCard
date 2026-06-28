import Foundation

final class InMemoryMediaStore: MediaStoring {
    private let publicBase: String
    private(set) var stored: [String: Data] = [:]
    init(publicBase: String) { self.publicBase = publicBase }

    func upload(_ data: Data, owner: UUID, card: UUID, kind: MediaKind) async throws -> URL {
        let path = cardMediaPath(owner: owner, card: card, kind: kind)
        stored[path] = data
        return URL(string: "\(publicBase)/card-media/\(path)")!
    }
}
