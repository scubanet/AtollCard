import SwiftUI

/// Presents the existing `CardEditorView` (which builds its own
/// `CardEditorViewModel(editing:)`) for the selected card. Thin wrapper so the
/// shell has a single, named entry point for editing.
struct EditSheet: View {
    let store: CardStoring
    let ownerId: UUID
    let card: Card

    var body: some View {
        CardEditorView(store: store, ownerId: ownerId, editing: card)
    }
}

#Preview {
    EditSheet(
        store: AppStores.preview.cardStore,
        ownerId: UUID(),
        card: Card(
            id: UUID(), ownerId: UUID(), slug: "demo",
            label: "Arbeit", displayName: "Demo",
            title: "Tester", company: "Acme",
            theme: "default", accentColor: "#0E7C86",
            visibility: .private, isActive: true
        )
    )
}
