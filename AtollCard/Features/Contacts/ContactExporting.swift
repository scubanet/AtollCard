import Foundation
import Contacts

/// Seam for saving a captured lead into the system address book.
protocol ContactExporting {
    func save(_ connection: Connection) async throws
}

/// Pure mapping from `Connection` to a `CNMutableContact` — testable without permissions.
enum ContactMapper {
    static func makeContact(from c: Connection) -> CNMutableContact {
        let contact = CNMutableContact()
        if let first = c.firstName, !first.isEmpty {
            contact.givenName = first
            contact.familyName = c.lastName ?? ""
        } else {
            let parts = c.name.split(separator: " ", maxSplits: 1).map(String.init)
            contact.givenName = parts.first ?? c.name
            contact.familyName = parts.count > 1 ? parts[1] : ""
        }
        if let email = c.email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = c.phone, !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                   value: CNPhoneNumber(stringValue: phone))]
        }
        if let company = c.company { contact.organizationName = company }
        if let note = c.note { contact.note = note }
        return contact
    }
}

/// Saves via `CNContactStore` after requesting access.
struct SystemContactExporter: ContactExporting {
    func save(_ connection: Connection) async throws {
        let store = CNContactStore()
        let granted = try await store.requestAccess(for: .contacts)
        guard granted else {
            throw NSError(domain: "AtollCard", code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Zugriff auf Kontakte nicht erlaubt. In den Einstellungen freigeben."])
        }
        let request = CNSaveRequest()
        request.add(ContactMapper.makeContact(from: connection), toContainerWithIdentifier: nil)
        try store.execute(request)
    }
}
