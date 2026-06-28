import Foundation
import Supabase

struct SupabaseAuthenticator: Authenticating {
    let client: SupabaseClient
    init(client: SupabaseClient = AtollSupabase.client) { self.client = client }

    func signIn(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(email: email, password: password)
        return session.user.id
    }
    func signOut() async throws {
        try await client.auth.signOut()
    }
}
