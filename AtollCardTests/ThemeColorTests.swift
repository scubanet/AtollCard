import XCTest
import SwiftUI
@testable import AtollCard

final class ThemeColorTests: XCTestCase {
    #if os(iOS)
    func test_appBGResolvesDifferentlyInDarkMode() {
        let light = UIColor(Theme.appBG).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark  = UIColor(Theme.appBG).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertNotEqual(light, dark, "appBG must differ between light and dark")
    }
    func test_textResolvesDifferentlyInDarkMode() {
        let light = UIColor(Theme.text).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark  = UIColor(Theme.text).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertNotEqual(light, dark)
    }
    #endif
}
