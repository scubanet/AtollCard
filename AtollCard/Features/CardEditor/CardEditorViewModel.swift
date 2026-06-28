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
    @Published var pendingCoverData: Data?
    @Published var pendingPhotoData: Data?
    var coverURL: String?
    var photoURL: String?
    var logoURL: String?

    private let store: CardStoring
    private let mediaStore: MediaStoring
    private let ownerId: UUID
    private let editingId: UUID?

    var isEditing: Bool { editingId != nil }

    init(store: CardStoring, mediaStore: MediaStoring, ownerId: UUID, editing: Card?) {
        self.store = store
        self.mediaStore = mediaStore
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
            coverURL = c.coverURL
            photoURL = c.photoURL
            logoURL = c.logoURL
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
        do {
            if let data = pendingCoverData {
                coverURL = try await mediaStore.upload(data, owner: ownerId, card: id, kind: .cover).absoluteString
            }
            if let data = pendingPhotoData {
                photoURL = try await mediaStore.upload(data, owner: ownerId, card: id, kind: .photo).absoluteString
            }
            let card = Card(id: id, ownerId: ownerId, slug: slug, label: label,
                            displayName: displayName,
                            title: title.isEmpty ? nil : title,
                            company: company.isEmpty ? nil : company,
                            theme: "default", accentColor: accentColor,
                            coverURL: coverURL, logoURL: logoURL, photoURL: photoURL,
                            visibility: visibility, isActive: true)
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
