import AppKit
import XCTest
@testable import VoiceType

@MainActor
final class TiroMenuBarIconTests: XCTestCase {
    func testMenuBarIconIsAnEighteenPointTemplateImage() {
        let image = TiroMenuBarIcon.make()

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertNotNil(image.tiffRepresentation)
    }
}
