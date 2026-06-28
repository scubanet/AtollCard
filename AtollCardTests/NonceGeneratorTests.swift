import XCTest
@testable import AtollCard

final class NonceGeneratorTests: XCTestCase {
    func test_sha256KnownVector() {
        XCTAssertEqual(NonceGenerator.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    func test_randomNonceLengthAndCharset() {
        let n = NonceGenerator.randomNonceString(length: 32)
        XCTAssertEqual(n.count, 32)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        XCTAssertTrue(n.allSatisfy { allowed.contains($0) })
    }
    func test_randomNonceIsUnique() {
        XCTAssertNotEqual(NonceGenerator.randomNonceString(), NonceGenerator.randomNonceString())
    }
}
