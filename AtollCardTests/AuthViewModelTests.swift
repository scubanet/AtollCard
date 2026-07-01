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
    func test_restoreSetsUserIdFromExistingSession() async {
        let id = UUID()
        let vm = AuthViewModel(authenticator: FakeAuthenticator(currentUserIdResult: id))
        XCTAssertTrue(vm.isRestoring)
        await vm.restore()
        XCTAssertEqual(vm.userId, id)
        XCTAssertFalse(vm.isRestoring)
    }
    func test_restoreWithNoSessionStaysSignedOut() async {
        let vm = AuthViewModel(authenticator: FakeAuthenticator())
        await vm.restore()
        XCTAssertNil(vm.userId)
        XCTAssertFalse(vm.isRestoring)
    }
    func test_deleteAccountSignsOutOnSuccess() async {
        let id = UUID()
        let vm = AuthViewModel(authenticator: FakeAuthenticator(currentUserIdResult: id))
        await vm.restore()
        XCTAssertEqual(vm.userId, id)
        await vm.deleteAccount()
        XCTAssertNil(vm.userId)
        XCTAssertNil(vm.errorMessage)
    }
    func test_deleteAccountFailureKeepsSessionAndSetsError() async {
        let id = UUID()
        var fake = FakeAuthenticator(currentUserIdResult: id)
        fake.deleteResult = .failure(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        let vm = AuthViewModel(authenticator: fake)
        await vm.restore()
        await vm.deleteAccount()
        XCTAssertEqual(vm.userId, id)
        XCTAssertEqual(vm.errorMessage, "boom")
    }
}

struct FakeAuthenticator: Authenticating {
    var result: Result<UUID, Error> = .failure(NSError(domain: "x", code: 0))
    var currentUserIdResult: UUID? = nil
    var deleteResult: Result<Void, Error> = .success(())
    func signIn(idToken: String, nonce: String) async throws -> UUID { try result.get() }
    func signOut() async throws {}
    func deleteAccount() async throws { try deleteResult.get() }
    func currentUserId() async -> UUID? { currentUserIdResult }
}
