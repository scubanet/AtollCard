import Foundation

enum CardVisibility: String, Codable, CaseIterable { case `public`, unlisted, `private` }

enum CardFieldType: String, Codable, CaseIterable {
    case phone, email, url, social, address, custom
}

struct CardField: Codable, Identifiable, Equatable {
    var id: UUID
    var type: CardFieldType
    var label: String
    var value: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, type, label, value
        case sortOrder = "sort_order"
    }
}

struct Card: Codable, Identifiable, Equatable {
    var id: UUID
    var ownerId: UUID
    var slug: String
    var label: String = "Karte"
    var displayName: String
    var title: String?
    var company: String?
    var theme: String
    var accentColor: String = "#0E7C86"
    var coverURL: String?
    var logoURL: String?
    var photoURL: String?
    var visibility: CardVisibility
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case slug, label
        case displayName = "display_name"
        case title, company, theme
        case accentColor = "accent_color"
        case coverURL = "cover_url"
        case logoURL = "logo_url"
        case photoURL = "photo_url"
        case visibility
        case isActive = "is_active"
    }
}

extension JSONDecoder {
    static let atoll: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
}

extension JSONEncoder {
    static let atoll: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
}
