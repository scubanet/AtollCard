import Foundation

struct AppStores {
    let cardStore: CardStoring
    let authenticator: Authenticating

    static let `default` = AppStores(
        cardStore: SupabaseCardStore(),
        authenticator: SupabaseAuthenticator()
    )

    static let preview = AppStores(
        cardStore: InMemoryCardStore(),
        authenticator: PreviewAuthenticator()
    )
}

/// App-target fake for SwiftUI previews (the test target has its own FakeAuthenticator).
struct PreviewAuthenticator: Authenticating {
    var userId: UUID = UUID()
    func signIn(email: String, password: String) async throws -> UUID { userId }
    func signOut() async throws {}
}
