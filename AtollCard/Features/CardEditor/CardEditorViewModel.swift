import Foundation

@MainActor
final class CardEditorViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var slug: String = ""
    @Published var label: String = "Karte"
    @Published var accentColor: String = "#0E7C86"
    @Published var title: String = ""
    @Published var company: String = ""
    @Published var visibility: CardVisibility = .private
    @Published var fields: [CardField] = []
    @Published var errorMessage: String?

    private let store: CardStoring
    private let ownerId: UUID
    private let editingId: UUID?

    var isEditing: Bool { editingId != nil }

    init(store: CardStoring, ownerId: UUID, editing: Card?) {
        self.store = store
        self.ownerId = ownerId
        self.editingId = editing?.id
        if let c = editing {
            displayName = c.displayName
            slug = c.slug
            label = c.label
            accentColor = c.accentColor
            title = c.title ?? ""
            company = c.company ?? ""
            visibility = c.visibility
        }
    }

    func addField(type: CardFieldType, label: String, value: String) {
        fields.append(CardField(id: UUID(), type: type, label: label,
                                value: value, sortOrder: fields.count))
    }

    func save() async -> Bool {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name darf nicht leer sein."
            return false
        }
        guard !slug.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Slug darf nicht leer sein."
            return false
        }
        let id = editingId ?? UUID()
        let card = Card(id: id, ownerId: ownerId, slug: slug, label: label,
                        displayName: displayName,
                        title: title.isEmpty ? nil : title,
                        company: company.isEmpty ? nil : company,
                        theme: "default", accentColor: accentColor,
                        coverURL: nil, logoURL: nil, photoURL: nil,
                        visibility: visibility, isActive: true)
        do {
            if editingId == nil {
                try await store.create(card, fields: fields)
            } else {
                try await store.update(card, fields: fields)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
