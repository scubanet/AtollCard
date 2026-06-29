import Foundation
import WidgetKit

protocol Authenticating {
    func signIn(idToken: String, nonce: String) async throws -> UUID
    func signOut() async throws
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var userId: UUID?
    @Published var errorMessage: String?

    var isSignedIn: Bool { userId != nil }
    private let authenticator: Authenticating

    init(authenticator: Authenticating) { self.authenticator = authenticator }

    func signIn(idToken: String, nonce: String) async {
        do {
            userId = try await authenticator.signIn(idToken: idToken, nonce: nonce)
            errorMessage = nil
        } catch {
            userId = nil
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await authenticator.signOut()
        userId = nil
        AtollAppGroup.save(nil)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
