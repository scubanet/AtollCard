import XCTest
@testable import AtollCard

final class SharedCardSnapshotTests: XCTestCase {
    func test_codableRoundTrip() throws {
        let snap = SharedCardSnapshot(slug: "jane-doe", displayName: "Jane Doe", accentColor: "#0E7C86")
        let data = try JSONEncoder().encode(snap)
        let back = try JSONDecoder().decode(SharedCardSnapshot.self, from: data)
        XCTAssertEqual(back, snap)
    }
}
