import CoreGraphics
import XCTest
@testable import VoiceType

final class ScreenshotGeometryTests: XCTestCase {
    func testUsableRectExcludesTopMenuBarAndBottomDock() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 50, width: 1512, height: 907)

        XCTAssertEqual(
            ScreenshotGeometry.sourceRect(screenFrame: screen, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 1512, height: 907)
        )
    }

    func testUsableRectAccountsForLeftDock() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let visible = CGRect(x: 76, y: 0, width: 1652, height: 1092)

        XCTAssertEqual(
            ScreenshotGeometry.sourceRect(screenFrame: screen, visibleFrame: visible),
            CGRect(x: 76, y: 25, width: 1652, height: 1092)
        )
    }

    func testUsableRectIsDisplayLocalForSecondaryScreen() {
        let screen = CGRect(x: -1920, y: 120, width: 1920, height: 1080)
        let visible = CGRect(x: -1920, y: 120, width: 1920, height: 1055)

        XCTAssertEqual(
            ScreenshotGeometry.sourceRect(screenFrame: screen, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 1920, height: 1055)
        )
    }
}

final class ScreenshotLinkFormatterTests: XCTestCase {
    func testWrapsLocalPathInSingleQuotesByDefault() {
        let fileURL = URL(fileURLWithPath: "/Users/example/Pictures/Tiro screenshots/Shot 1.png")

        XCTAssertEqual(
            ScreenshotLinkFormatter.link(for: fileURL),
            "'/Users/example/Pictures/Tiro screenshots/Shot 1.png'"
        )
    }

    func testCanLeavePathPlain() {
        let fileURL = URL(fileURLWithPath: "/tmp/plain.png")

        XCTAssertEqual(
            ScreenshotLinkFormatter.link(for: fileURL, wrapper: .plain),
            "/tmp/plain.png"
        )
    }

    func testSupportsCustomTextAroundPath() {
        let fileURL = URL(fileURLWithPath: "/tmp/diagram.png")
        let markdown = ScreenshotPathWrapper(
            isEnabled: true,
            prefix: "![diagram](",
            suffix: ")"
        )

        XCTAssertEqual(
            ScreenshotLinkFormatter.link(for: fileURL, wrapper: markdown),
            "![diagram](/tmp/diagram.png)"
        )
    }

    func testEnabledWrapperAllowsBlankSides() {
        let wrapper = ScreenshotPathWrapper(
            isEnabled: true,
            prefix: "",
            suffix: ""
        )

        XCTAssertEqual(wrapper.format("/tmp/plain.png"), "/tmp/plain.png")
    }

    func testDisabledWrapperIgnoresSavedAffixes() {
        let wrapper = ScreenshotPathWrapper(
            isEnabled: false,
            prefix: "<",
            suffix: ">"
        )

        XCTAssertEqual(wrapper.format("/tmp/plain.png"), "/tmp/plain.png")
    }

    func testDefaultWrapperUsesSingleQuotes() {
        XCTAssertEqual(
            ScreenshotPathWrapper.defaultValue,
            ScreenshotPathWrapper(isEnabled: true, prefix: "'", suffix: "'")
        )
    }

    func testAppendsMultipleLinksInCaptureOrder() {
        let first = URL(fileURLWithPath: "/tmp/first.png")
        let second = URL(fileURLWithPath: "/tmp/second.png")

        XCTAssertEqual(
            ScreenshotLinkFormatter.appending([first, second], to: "Meeting notes"),
            "Meeting notes\n\n'/tmp/first.png'\n'/tmp/second.png'"
        )
    }

    func testLeavesTranscriptUnchangedWithoutScreenshots() {
        XCTAssertEqual(
            ScreenshotLinkFormatter.appending([], to: "No images"),
            "No images"
        )
    }
}
