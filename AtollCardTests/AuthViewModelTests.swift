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
        await vm.signIn(email: "a@b.com", password: "pw")
        XCTAssertTrue(vm.isSignedIn)
        XCTAssertEqual(vm.userId, id)
    }

    func test_signInFailureSetsError() async {
        let vm = AuthViewModel(authenticator: FakeAuthenticator(result: .failure(
            NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad creds"]))))
        await vm.signIn(email: "a@b.com", password: "wrong")
        XCTAssertFalse(vm.isSignedIn)
        XCTAssertEqual(vm.errorMessage, "bad creds")
    }
}

struct FakeAuthenticator: Authenticating {
    var result: Result<UUID, Error> = .failure(NSError(domain: "x", code: 0))
    func signIn(email: String, password: String) async throws -> UUID {
        try result.get()
    }
    func signOut() async throws {}
}
