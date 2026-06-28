import Foundation
import Supabase

struct SupabaseMediaStore: MediaStoring {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func upload(_ data: Data, owner: UUID, card: UUID, kind: MediaKind) async throws -> URL {
        let path = cardMediaPath(owner: owner, card: card, kind: kind)
        try await client.storage.from("card-media")
            .upload(path, data: data,
                    options: FileOptions(cacheControl: "3600", upsert: true))
        return try client.storage.from("card-media").getPublicURL(path: path)
    }
}
