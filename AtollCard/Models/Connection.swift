import Foundation

struct Connection: Codable, Identifiable, Equatable {
    var id: UUID
    var cardId: UUID
    var name: String
    var email: String?
    var phone: String?
    var company: String?
    var note: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, company, note
        case cardId = "card_id"
        case createdAt = "created_at"
    }
}
