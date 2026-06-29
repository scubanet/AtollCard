import XCTest
@testable import AtollCard

final class EmailSignatureBuilderTests: XCTestCase {
    private func card(slug: String = "jane-doe") -> Card {
        Card(id: UUID(), ownerId: UUID(), slug: slug, displayName: "Jane Doe",
             title: "CTO", company: "Acme", theme: "default", accentColor: "#0E7C86",
             coverURL: nil, logoURL: nil, photoURL: nil, visibility: .public, isActive: true)
    }
    private let fields = [
        CardField(id: UUID(), type: .email, label: "Work", value: "jane@acme.com", sortOrder: 0),
        CardField(id: UUID(), type: .phone, label: "Mobil", value: "+41 79", sortOrder: 1),
    ]

    func test_htmlContainsCoreContent() {
        let html = EmailSignatureBuilder.html(for: card(), fields: fields)
        XCTAssertTrue(html.contains("Jane Doe"))
        XCTAssertTrue(html.contains("CTO"))
        XCTAssertTrue(html.contains("Acme"))
        XCTAssertTrue(html.contains("mailto:jane@acme.com"))
        XCTAssertTrue(html.contains("tel:+41 79"))
        XCTAssertTrue(html.contains("card.atoll-os.com/jane-doe"))
        XCTAssertFalse(html.contains("<img"), "no photo in signature")
    }

    func test_htmlEscapesValues() {
        let f = [CardField(id: UUID(), type: .custom, label: "X", value: "A & <B>", sortOrder: 0)]
        let html = EmailSignatureBuilder.html(for: card(), fields: f)
        XCTAssertTrue(html.contains("A &amp; &lt;B&gt;"))
        XCTAssertFalse(html.contains("A & <B>"))
    }

    func test_plainTextHasNoTags() {
        let plain = EmailSignatureBuilder.plainText(for: card(), fields: fields)
        XCTAssertTrue(plain.contains("Jane Doe"))
        XCTAssertTrue(plain.contains("jane@acme.com"))
        XCTAssertTrue(plain.contains("https://card.atoll-os.com/jane-doe"))
        XCTAssertFalse(plain.contains("<"))
    }
}
