import XCTest
@testable import AtollCard

final class CardModelTests: XCTestCase {
    func test_decodesCardFromSupabaseJSON() throws {
        let json = """
        {"id":"cccccccc-0000-0000-0000-000000000001",
         "owner_id":"aaaaaaaa-0000-0000-0000-000000000001",
         "slug":"jane-doe","label":"Arbeit","display_name":"Jane Doe","title":"CTO",
         "company":"Acme","theme":"default","accent_color":"#0E7C86",
         "cover_url":null,"logo_url":null,"photo_url":null,
         "visibility":"public","is_active":true}
        """.data(using: .utf8)!
        let card = try JSONDecoder.atoll.decode(Card.self, from: json)
        XCTAssertEqual(card.slug, "jane-doe")
        XCTAssertEqual(card.displayName, "Jane Doe")
        XCTAssertEqual(card.label, "Arbeit")
        XCTAssertEqual(card.accentColor, "#0E7C86")
        XCTAssertEqual(card.visibility, .public)
    }

    func test_fieldTypeRoundTrips() throws {
        let field = CardField(id: UUID(), type: .email, label: "Work", value: "j@acme.com", sortOrder: 0)
        let data = try JSONEncoder.atoll.encode(field)
        let back = try JSONDecoder.atoll.decode(CardField.self, from: data)
        XCTAssertEqual(back.type, .email)
    }
}
