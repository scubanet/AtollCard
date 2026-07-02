import XCTest
import Contacts
@testable import AtollCard

final class ContactExportTests: XCTestCase {
    func test_mapsSplitNamesAndFields() {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Max Muster",
            firstName: "Max", lastName: "Muster", email: "m@x.co", phone: "+41 79",
            company: "Acme", note: "Messe", createdAt: Date())
        let contact = ContactMapper.makeContact(from: c)
        XCTAssertEqual(contact.givenName, "Max")
        XCTAssertEqual(contact.familyName, "Muster")
        XCTAssertEqual(contact.emailAddresses.first?.value as String?, "m@x.co")
        XCTAssertEqual(contact.phoneNumbers.first?.value.stringValue, "+41 79")
        XCTAssertEqual(contact.organizationName, "Acme")
        XCTAssertEqual(contact.note, "Messe")
    }
    func test_fallbackSplitsLegacyName() {
        let c = Connection(id: UUID(), cardId: UUID(), name: "Erika Beispiel Frau",
            firstName: nil, lastName: nil, email: nil, phone: nil,
            company: nil, note: nil, createdAt: Date())
        let contact = ContactMapper.makeContact(from: c)
        XCTAssertEqual(contact.givenName, "Erika")
        XCTAssertEqual(contact.familyName, "Beispiel Frau")
    }
}
