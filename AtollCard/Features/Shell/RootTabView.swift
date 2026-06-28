import SwiftUI

/// Signed-in root. iOS: custom floating glass 3-tab bar over the content.
/// macOS: standard `TabView` (a floating bar is impractical there).
struct RootTabView: View {
    private let store: CardStoring
    private let mediaStore: MediaStoring
    private let ownerId: UUID
    @ObservedObject var authVM: AuthViewModel

    @StateObject private var vm: CardListViewModel
    @State private var selectedTab: ShellTab = .card
    @State private var selectedCardId: UUID?

    init(store: CardStoring, mediaStore: MediaStoring, ownerId: UUID, authVM: AuthViewModel) {
        self.store = store
        self.mediaStore = mediaStore
        self.ownerId = ownerId
        self.authVM = authVM
        _vm = StateObject(wrappedValue: CardListViewModel(store: store, ownerId: ownerId))
    }

    private var selectedCard: Card? {
        if let id = selectedCardId, let c = vm.cards.first(where: { $0.id == id }) { return c }
        return vm.cards.first
    }

    var body: some View {
        #if os(iOS)
        iosShell
            .task { await loadAndSelect() }
        #else
        macShell
            .task { await loadAndSelect() }
        #endif
    }

    private func loadAndSelect() async {
        await vm.load()
        if selectedCardId == nil { selectedCardId = vm.cards.first?.id }
    }

    // MARK: - iOS custom floating bar

    #if os(iOS)
    private var iosShell: some View {
        ZStack(alignment: .bottom) {
            Theme.appBG.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .card:
                    MyCardScreen(store: store, mediaStore: mediaStore, ownerId: ownerId, vm: vm,
                                 selectedCardId: $selectedCardId)
                case .contacts:
                    ContactsView()
                case .settings:
                    SettingsView(authVM: authVM)
                }
            }

            FloatingTabBar(selection: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }
    #endif

    // MARK: - macOS standard TabView

    #if os(macOS)
    private var macShell: some View {
        TabView(selection: $selectedTab) {
            MyCardScreen(store: store, mediaStore: mediaStore, ownerId: ownerId, vm: vm,
                         selectedCardId: $selectedCardId)
                .tabItem { Label("Karte", systemImage: "person.text.rectangle") }
                .tag(ShellTab.card)

            ContactsView()
                .tabItem { Label("Kontakte", systemImage: "person.2") }
                .tag(ShellTab.contacts)

            SettingsView(authVM: authVM)
                .tabItem { Label("Einstellungen", systemImage: "sun.max") }
                .tag(ShellTab.settings)
        }
    }
    #endif
}

enum ShellTab: Hashable {
    case card, contacts, settings
}

#Preview {
    RootTabView(
        store: AppStores.preview.cardStore,
        mediaStore: AppStores.preview.mediaStore,
        ownerId: UUID(),
        authVM: AuthViewModel(authenticator: AppStores.preview.authenticator)
    )
}
