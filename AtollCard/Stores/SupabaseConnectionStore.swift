import Foundation
import Supabase

final class SupabaseConnectionStore: ConnectionStoring {
    private let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }
    func connections(forOwner ownerId: UUID) async throws -> [Connection] {
        try await client.from("connections")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    func delete(_ connectionId: UUID) async throws {
        try await client.from("connections").delete()
            .eq("id", value: connectionId.uuidString).execute()
    }
}
