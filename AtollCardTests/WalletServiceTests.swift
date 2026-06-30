import XCTest
@testable import AtollCard

@MainActor
final class WalletServiceTests: XCTestCase {
    func test_viewModelLoadsPassData() async {
        let data = Data([0x50, 0x4B]) // "PK" zip magic
        let vm = WalletAddViewModel(service: FakeWalletService(result: .success(data)))
        await vm.fetch(cardId: UUID())
        XCTAssertEqual(vm.passData, data)
        XCTAssertNil(vm.errorMessage)
    }
    func test_viewModelSurfacesError() async {
        let vm = WalletAddViewModel(service: FakeWalletService(result: .failure(
            NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "nope"]))))
        await vm.fetch(cardId: UUID())
        XCTAssertNil(vm.passData)
        XCTAssertEqual(vm.errorMessage, "nope")
    }
}

struct FakeWalletService: WalletPassProviding {
    var result: Result<Data, Error>
    func passData(forCardId id: UUID) async throws -> Data { try result.get() }
}
