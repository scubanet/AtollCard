import SwiftUI

@main
struct AtollCardApp: App {
    private let stores: AppStores
    @StateObject private var authVM: AuthViewModel

    init() {
        AtollFonts.registerBundledFonts()
        let stores = AppStores.default
        self.stores = stores
        _authVM = StateObject(wrappedValue: AuthViewModel(authenticator: stores.authenticator))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isRestoring {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.appBG.ignoresSafeArea())
                } else if let userId = authVM.userId {
                    RootTabView(store: stores.cardStore, mediaStore: stores.mediaStore,
                                connectionStore: stores.connectionStore,
                                ownerId: userId, authVM: authVM)
                } else {
                    SignInView(authVM: authVM)
                }
            }
            .task { await authVM.restore() }
        }
    }
}
