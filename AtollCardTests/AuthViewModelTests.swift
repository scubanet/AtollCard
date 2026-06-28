import XCTest
@testable import AtollCard

@MainActor
final class AuthViewModelTests: XCTestCase {
    func test_signedOutByDefault() {
        let vm = AuthViewModel(authenticator: FakeAuthenticator())
        XCTAssertFalse(vm.isSignedIn)
        XCTAssertNil(vm.userId)
    }
    func test_signInSetsUserId() async {
        let id = UUID()
        let vm = AuthViewModel(authenticator: FakeAuthenticator(result: .success(id)))
        await vm.signIn(idToken: "tok", nonce: "n")
        XCTAssertTrue(vm.isSignedIn)
        XCTAssertEqual(vm.userId, id)
    }
    func test_signInFailureSetsError() async {
        let vm = AuthViewModel(authenticator: FakeAuthenticator(result: .failure(
            NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad token"]))))
        await vm.signIn(idToken: "tok", nonce: "n")
        XCTAssertFalse(vm.isSignedIn)
        XCTAssertEqual(vm.errorMessage, "bad token")
    }
}

struct FakeAuthenticator: Authenticating {
    var result: Result<UUID, Error> = .failure(NSError(domain: "x", code: 0))
    func signIn(idToken: String, nonce: String) async throws -> UUID { try result.get() }
    func signOut() async throws {}
}
