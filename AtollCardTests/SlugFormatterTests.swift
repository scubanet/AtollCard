import XCTest
@testable import AtollCard

final class SlugFormatterTests: XCTestCase {
    func test_simpleName_lowercasedAndHyphenated() {
        XCTAssertEqual(SlugFormatter.normalize("Jane Doe"), "jane-doe")
    }

    func test_leadingTrailingWhitespace_trimmedAndCollapsed() {
        XCTAssertEqual(SlugFormatter.normalize("  Leading  Trailing  "), "leading-trailing")
    }

    func test_repeatedHyphens_collapsedAndTrimmed() {
        XCTAssertEqual(SlugFormatter.normalize("--already--hyphenated--"), "already-hyphenated")
    }

    func test_punctuation_stripped() {
        XCTAssertEqual(SlugFormatter.normalize("O'Brien!!"), "obrien")
    }
}
