import Foundation

protocol Authenticating {
    func signIn(email: String, password: String) async throws -> UUID
    func signOut() async throws
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var userId: UUID?
    @Published var errorMessage: String?

    var isSignedIn: Bool { userId != nil }
    private let authenticator: Authenticating

    init(authenticator: Authenticating) { self.authenticator = authenticator }

    func signIn(email: String, password: String) async {
        do {
            userId = try await authenticator.signIn(email: email, password: password)
            errorMessage = nil
        } catch {
            userId = nil
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await authenticator.signOut()
        userId = nil
    }
}
