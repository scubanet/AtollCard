import Foundation
import Supabase

struct SupabaseAuthenticator: Authenticating {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func signIn(idToken: String, nonce: String) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        return session.user.id
    }
    func signOut() async throws { try await client.auth.signOut() }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        try? await client.auth.signOut()
    }

    func currentUserId() async -> UUID? {
        (try? await client.auth.session)?.user.id
    }
}
