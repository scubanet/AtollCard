import XCTest
import CoreImage
@testable import AtollCard

final class QRCodeGeneratorTests: XCTestCase {
    func test_profileURLForSlug() {
        let url = QRCodeGenerator.profileURL(forSlug: "jane-doe")
        XCTAssertEqual(url.absoluteString, "https://card.atoll-os.com/jane-doe")
    }

    func test_generatesNonEmptyImageForURL() throws {
        let image = QRCodeGenerator.image(for: URL(string: "https://card.atoll-os.com/jane-doe")!)
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image!.extent.width, 0)
    }
}
