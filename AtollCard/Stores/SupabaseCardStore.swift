import Foundation
import Supabase

final class SupabaseCardStore: CardStoring {
    private let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func cards(forOwner ownerId: UUID) async throws -> [Card] {
        try await client.from("cards")
            .select()
            .eq("owner_id", value: ownerId.uuidString)
            .order("slug")
            .execute()
            .value
    }

    func fields(forCard cardId: UUID) async throws -> [CardField] {
        try await client.from("card_fields")
            .select()
            .eq("card_id", value: cardId.uuidString)
            .order("sort_order")
            .execute()
            .value
    }

    func create(_ card: Card, fields: [CardField]) async throws {
        try await client.from("cards").insert(card).execute()
        if !fields.isEmpty {
            try await client.from("card_fields").insert(fields.map {
                CardFieldInsert(card_id: card.id, type: $0.type, label: $0.label,
                                value: $0.value, sort_order: $0.sortOrder)
            }).execute()
        }
    }

    func update(_ card: Card, fields: [CardField]) async throws {
        try await client.from("cards").update(card).eq("id", value: card.id.uuidString).execute()
        try await client.from("card_fields").delete().eq("card_id", value: card.id.uuidString).execute()
        if !fields.isEmpty {
            try await client.from("card_fields").insert(fields.map {
                CardFieldInsert(card_id: card.id, type: $0.type, label: $0.label,
                                value: $0.value, sort_order: $0.sortOrder)
            }).execute()
        }
    }

    func delete(_ cardId: UUID) async throws {
        try await client.from("cards").delete().eq("id", value: cardId.uuidString).execute()
    }

    func slugIsAvailable(_ slug: String) async throws -> Bool {
        try await client.rpc("slug_available", params: ["p_slug": slug])
            .execute()
            .value
    }

    private struct CardFieldInsert: Encodable {
        let card_id: UUID
        let type: CardFieldType
        let label: String
        let value: String
        let sort_order: Int
    }
}
