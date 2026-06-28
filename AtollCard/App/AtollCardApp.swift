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
            if let userId = authVM.userId {
                CardListView(store: stores.cardStore, ownerId: userId, authVM: authVM)
            } else {
                SignInView(authVM: authVM)
            }
        }
    }
}
