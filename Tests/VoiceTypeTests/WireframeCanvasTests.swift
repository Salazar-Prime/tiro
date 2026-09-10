import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
@testable import VoiceType

final class WireframeGeometryTests: XCTestCase {
    func testRectangleUsesOppositeCornersInEitherOrder() {
        let geometry = WireframeGeometryFactory.rectangle(
            from: CGPoint(x: 120, y: 90),
            to: CGPoint(x: 20, y: 30)
        )

        XCTAssertEqual(geometry.bounds, CGRect(x: 20, y: 30, width: 100, height: 60))
    }

    func testCircleUsesFirstPointAsCenter() {
        let geometry = WireframeGeometryFactory.circle(
            center: CGPoint(x: 40, y: 50),
            edge: CGPoint(x: 70, y: 90)
        )

        guard case let .circle(center, radius) = geometry else {
            return XCTFail("Expected circle geometry")
        }
        XCTAssertEqual(center, CGPoint(x: 40, y: 50))
        XCTAssertEqual(radius, 50, accuracy: 0.001)
    }

    func testEllipseUsesTwoMajorAxisEndsAndPerpendicularMinorRadius() {
        let geometry = WireframeGeometryFactory.ellipse(
            majorAxisStart: CGPoint(x: 10, y: 20),
            majorAxisEnd: CGPoint(x: 110, y: 20),
            minorAxisPoint: CGPoint(x: 60, y: 50)
        )

        guard case let .ellipse(center, majorRadius, minorRadius, rotation) = geometry else {
            return XCTFail("Expected ellipse geometry")
        }
        XCTAssertEqual(center, CGPoint(x: 60, y: 20))
        XCTAssertEqual(majorRadius, 50, accuracy: 0.001)
        XCTAssertEqual(minorRadius, 30, accuracy: 0.001)
        XCTAssertEqual(rotation, 0, accuracy: 0.001)
    }

    func testPanelIsSquareAndAnchoredAtRightCenter() {
        let visibleFrame = CGRect(x: 76, y: 50, width: 1512, height: 907)
        let frame = WireframePanelGeometry.frame(in: visibleFrame)

        XCTAssertEqual(frame.width, 504, accuracy: 0.001)
        XCTAssertEqual(frame.height, 504, accuracy: 0.001)
        XCTAssertEqual(frame.maxX, visibleFrame.maxX - 18, accuracy: 0.001)
        XCTAssertEqual(frame.midY, visibleFrame.midY, accuracy: 0.001)
    }

    func testMobileBrowserAndDottedFramesUseTheChosenCorners() {
        let first = CGPoint(x: 240, y: 320)
        let second = CGPoint(x: 40, y: 80)

        let mobile = WireframeGeometryFactory.mobileFrame(from: first, to: second)
        let browser = WireframeGeometryFactory.browserFrame(from: first, to: second)
        let dotted = WireframeGeometryFactory.dottedFrame(from: first, to: second)

        XCTAssertEqual(mobile.bounds, CGRect(x: 40, y: 80, width: 200, height: 240))
        XCTAssertEqual(browser.bounds, CGRect(x: 40, y: 80, width: 200, height: 240))
        XCTAssertEqual(dotted.bounds, CGRect(x: 40, y: 80, width: 200, height: 240))
    }
}

@MainActor
final class WireframeCanvasModelTests: XCTestCase {
    func testCompletedShapeImmediatelyStartsNamingAndSavesColoredLabelText() {
        let model = WireframeCanvasModel()

        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))

        XCTAssertEqual(model.elements.count, 1)
        XCTAssertEqual(model.namingElementID, model.elements[0].id)

        model.namingText = "Search field"
        model.submitName()

        XCTAssertEqual(model.elements[0].name, "Search field")
        XCTAssertNil(model.namingElementID)
    }

    func testTwoBlankReturnsLeaveNewShapeUnnamed() {
        let model = WireframeCanvasModel()
        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))

        model.submitName()

        XCTAssertTrue(model.namingSkipIsArmed)
        XCTAssertNotNil(model.namingElementID)

        model.submitName()

        XCTAssertEqual(model.elements[0].name, "")
        XCTAssertNil(model.namingElementID)
    }

    func testRenameToolSelectsElementOnlyNearItsBorder() {
        let model = WireframeCanvasModel()
        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))
        model.submitName()
        model.submitName()
        model.selectTool(.rename)

        model.handleClick(at: CGPoint(x: 70, y: 60))
        XCTAssertNil(model.namingElementID)

        model.handleClick(at: CGPoint(x: 20, y: 60))
        XCTAssertEqual(model.namingElementID, model.elements[0].id)
    }

    func testClickingCanvasOutsideNameFieldCommitsTheNameWithoutDrawing() {
        let model = WireframeCanvasModel()
        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))
        model.namingText = "Primary action"

        model.handleClick(at: CGPoint(x: 250, y: 250))

        XCTAssertEqual(model.elements[0].name, "Primary action")
        XCTAssertNil(model.namingElementID)
        XCTAssertTrue(model.draftPoints.isEmpty)
    }

    func testClickingAwayAfterClearingANameRemovesTheLabel() {
        let model = WireframeCanvasModel()
        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))
        model.namingText = "Old name"
        model.submitName()
        model.selectTool(.rename)
        model.handleClick(at: CGPoint(x: 20, y: 60))
        model.namingText = ""

        model.handleClick(at: CGPoint(x: 250, y: 250))

        XCTAssertEqual(model.elements[0].name, "")
        XCTAssertNil(model.namingElementID)
    }

    func testMobileFrameIsCreatedWithTwoClicksAndStartsNaming() {
        let model = WireframeCanvasModel()
        model.selectTool(.mobileFrame)

        model.handleClick(at: CGPoint(x: 40, y: 60))
        model.handleClick(at: CGPoint(x: 140, y: 260))

        XCTAssertEqual(model.elements.count, 1)
        XCTAssertEqual(model.elements[0].geometry.bounds, CGRect(x: 40, y: 60, width: 100, height: 200))
        XCTAssertEqual(model.namingElementID, model.elements[0].id)
    }

    func testDottedFrameIsCreatedAndItsToolNameIsVisible() {
        let model = WireframeCanvasModel()
        model.selectTool(.dottedFrame)

        XCTAssertTrue(model.statusText.hasPrefix("Dotted frame ·"))
        model.handleClick(at: CGPoint(x: 40, y: 60))
        model.handleClick(at: CGPoint(x: 160, y: 180))

        XCTAssertEqual(model.elements.count, 1)
        guard case .dottedFrame = model.elements[0].geometry else {
            return XCTFail("Expected a dotted frame")
        }
    }

    func testPinCanKeepBoardVisibleAndClearAllPreservesPin() {
        let model = WireframeCanvasModel()
        model.togglePin()
        model.handleClick(at: CGPoint(x: 20, y: 30))
        model.handleClick(at: CGPoint(x: 120, y: 90))

        model.clearAll()

        XCTAssertTrue(model.isPinned)
        XCTAssertTrue(model.elements.isEmpty)
        XCTAssertTrue(model.draftPoints.isEmpty)
        XCTAssertNil(model.namingElementID)
        XCTAssertFalse(model.canClearAll)
    }

    func testExportLayoutIsATightSquareAroundAllElements() {
        let elements = [
            WireframeElement(geometry: .rectangle(CGRect(x: 40, y: 80, width: 200, height: 100))),
            WireframeElement(geometry: .circle(center: CGPoint(x: 300, y: 150), radius: 20))
        ]

        let layout = WireframeExportLayout(elements: elements)

        XCTAssertEqual(layout.sourceRect.width, layout.sourceRect.height, accuracy: 0.001)
        XCTAssertTrue(layout.sourceRect.contains(elements[0].geometry.bounds))
        XCTAssertTrue(layout.sourceRect.contains(elements[1].geometry.bounds))
        XCTAssertEqual(layout.translatedElements.count, 2)
        XCTAssertEqual(layout.translatedElements[0].geometry.bounds.minX, WireframeExportLayout.padding)
    }

    func testExporterWritesPNGAndReusesUnchangedImage() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiro-wireframe-export-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        var fileURLRequestCount = 0
        let exporter = WireframeExporter(
            pathWrapper: { .defaultValue },
            fileURLProvider: {
                fileURLRequestCount += 1
                return outputURL
            }
        )
        let elements = [
            WireframeElement(
                geometry: .browserFrame(CGRect(x: 30, y: 50, width: 240, height: 160)),
                name: "Dashboard"
            )
        ]

        let firstResult = exporter.perform(
            .save,
            elements: elements,
            revision: 1,
            colorScheme: .light
        )
        let secondResult = exporter.perform(
            .save,
            elements: elements,
            revision: 1,
            colorScheme: .light
        )

        let data = try Data(contentsOf: outputURL)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        XCTAssertEqual(bitmap.pixelsWide, bitmap.pixelsHigh)
        XCTAssertEqual(bitmap.pixelsWide, 552)
        XCTAssertEqual(firstResult.message, "Saved in Tiro screenshots")
        XCTAssertEqual(secondResult.message, "Saved in Tiro screenshots")
        XCTAssertEqual(fileURLRequestCount, 1)
    }

    func testAppendSavesAndAddsLinkToCurrentClipboardText() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiro-wireframe-append-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        var clipboardText = "Existing clipboard note"
        let exporter = WireframeExporter(
            pathWrapper: {
                ScreenshotPathWrapper(isEnabled: false, prefix: "", suffix: "")
            },
            fileURLProvider: { outputURL },
            readClipboardText: { clipboardText },
            writeClipboardText: { value in
                clipboardText = value
                return true
            }
        )

        let result = exporter.perform(
            .appendLink,
            elements: [
                WireframeElement(
                    geometry: .rectangle(CGRect(x: 10, y: 10, width: 80, height: 40))
                )
            ],
            revision: 1,
            colorScheme: .light
        )

        XCTAssertEqual(result.message, "Saved and appended to clipboard")
        XCTAssertEqual(clipboardText, "Existing clipboard note\n\n\(outputURL.path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }
}
