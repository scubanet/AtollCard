import Foundation

struct AppStores {
    let cardStore: CardStoring
    let mediaStore: MediaStoring
    let connectionStore: ConnectionStoring
    let authenticator: Authenticating

    static let `default` = AppStores(
        cardStore: SupabaseCardStore(),
        mediaStore: SupabaseMediaStore(),
        connectionStore: SupabaseConnectionStore(),
        authenticator: SupabaseAuthenticator()
    )

    static let preview = AppStores(
        cardStore: InMemoryCardStore(),
        mediaStore: InMemoryMediaStore(publicBase: "https://preview.supabase.co/storage/v1/object/public"),
        connectionStore: InMemoryConnectionStore(),
        authenticator: PreviewAuthenticator()
    )
}

/// App-target fake for SwiftUI previews (the test target has its own FakeAuthenticator).
struct PreviewAuthenticator: Authenticating {
    var userId: UUID = UUID()
    func signIn(idToken: String, nonce: String) async throws -> UUID { userId }
    func signOut() async throws {}
    func currentUserId() async -> UUID? { userId }
}
