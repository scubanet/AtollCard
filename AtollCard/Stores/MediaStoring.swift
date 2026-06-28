import Foundation

enum MediaKind: String { case cover, photo }

protocol MediaStoring {
    func upload(_ data: Data, owner: UUID, card: UUID, kind: MediaKind) async throws -> URL
}

func cardMediaPath(owner: UUID, card: UUID, kind: MediaKind) -> String {
    "\(owner.uuidString.lowercased())/\(card.uuidString.lowercased())/\(kind.rawValue)"
}
