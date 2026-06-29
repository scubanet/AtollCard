import XCTest
@testable import AtollCard

final class AtollAppGroupTests: XCTestCase {
    private let suite = "group.test.atollcard"
    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }
    func test_saveThenLoadRoundTrips() {
        let snap = SharedCardSnapshot(slug: "s", displayName: "N", accentColor: "#0E7C86")
        AtollAppGroup.save(snap, suiteName: suite)
        XCTAssertEqual(AtollAppGroup.load(suiteName: suite), snap)
    }
    func test_saveNilClears() {
        let snap = SharedCardSnapshot(slug: "s", displayName: "N", accentColor: "#0E7C86")
        AtollAppGroup.save(snap, suiteName: suite)
        AtollAppGroup.save(nil, suiteName: suite)
        XCTAssertNil(AtollAppGroup.load(suiteName: suite))
    }
}
