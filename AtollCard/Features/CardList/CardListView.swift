import SwiftUI

struct CardListView: View {
    private let store: CardStoring
    private let mediaStore: MediaStoring
    private let ownerId: UUID
    @ObservedObject var authVM: AuthViewModel

    @StateObject private var vm: CardListViewModel
    @State private var isPresentingEditor = false

    init(store: CardStoring, mediaStore: MediaStoring, ownerId: UUID, authVM: AuthViewModel) {
        self.store = store
        self.mediaStore = mediaStore
        self.ownerId = ownerId
        self.authVM = authVM
        _vm = StateObject(wrappedValue: CardListViewModel(store: store, ownerId: ownerId))
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                ForEach(vm.cards) { card in
                    NavigationLink {
                        ShareCardView(slug: card.slug)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.displayName)
                                .font(.headline)
                            Text(card.slug)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Karten")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label("Karte hinzufügen", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abmelden") {
                        Task { await authVM.signOut() }
                    }
                }
            }
            .task { await vm.load() }
            .sheet(isPresented: $isPresentingEditor, onDismiss: {
                Task { await vm.load() }
            }) {
                CardEditorView(store: store, mediaStore: mediaStore, ownerId: ownerId)
            }
        }
    }
}

#Preview {
    CardListView(
        store: AppStores.preview.cardStore,
        mediaStore: AppStores.preview.mediaStore,
        ownerId: UUID(),
        authVM: AuthViewModel(authenticator: AppStores.preview.authenticator)
    )
}
