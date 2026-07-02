import Foundation

struct Connection: Codable, Identifiable, Equatable {
    var id: UUID
    var cardId: UUID
    var name: String
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var company: String?
    var note: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, company, note
        case cardId = "card_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
    }

    var displayName: String {
        let combined = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? name : combined
    }
}
