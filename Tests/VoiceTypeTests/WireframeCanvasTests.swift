import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import XCTest
@testable import VoiceType

final class WireframeGeometryTests: XCTestCase {
    func testGlassHighlightAndLabelAreOneContinuousContourAcrossToolbarBoundary() {
        let rect = CGRect(x: 0, y: 0, width: 272, height: 76)
        // Include edge buttons and intermediate positions during the slide.
        for x in stride(from: CGFloat(19), through: 253, by: 9) {
            let shape = WireframeGlassShape(buttonX: x, buttonTop: 5, toolbarHeight: 38)
            let path = shape.path(in: rect)
            var moves = 0
            var closes = 0
            path.forEach { element in
                switch element {
                case .move: moves += 1
                case .closeSubpath: closes += 1
                default: break
                }
            }
            XCTAssertEqual(moves, 1)
            XCTAssertEqual(closes, 1)
            for y in stride(from: CGFloat(6), through: 71, by: 0.5) {
                XCTAssertTrue(path.contains(CGPoint(x: x, y: y)), "Disconnected at \(x), \(y)")
            }
            XCTAssertGreaterThanOrEqual(path.boundingRect.minX, 0)
            XCTAssertLessThanOrEqual(path.boundingRect.maxX, rect.width)
            XCTAssertEqual(shape.labelBounds(in: rect).height, 26)
        }
    }

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
    func testNewBoardDefaultsToMobilePhoneFrame() {
        let model = WireframeCanvasModel()
        XCTAssertEqual(model.selectedTool, .mobileFrame)
        model.handleClick(at: CGPoint(x: 100, y: 100))
        model.handleClick(at: CGPoint(x: 180, y: 260))
        guard case .mobileFrame = model.elements.first?.geometry else {
            return XCTFail("The initial tool should draw a mobile phone frame")
        }
    }

    func testPanelRoutesEscapeWithoutCanvasFocusAndIgnoresKeyRepeat() throws {
        let panel = WireframePanel(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless], backing: .buffered, defer: true
        )
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        model.handleClick(at: CGPoint(x: 10, y: 10))
        var closeCount = 0
        panel.onEscape = {
            if !model.handleEscape() { closeCount += 1 }
        }
        func event(repeating: Bool) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                isARepeat: repeating, keyCode: 53
            ))
        }
        panel.sendEvent(try event(repeating: false))
        XCTAssertTrue(model.draftPoints.isEmpty)
        XCTAssertEqual(closeCount, 0)
        panel.sendEvent(try event(repeating: true))
        XCTAssertEqual(closeCount, 0, "Holding Escape must not cancel then immediately close")
        panel.sendEvent(try event(repeating: false))
        XCTAssertEqual(closeCount, 1)
    }

    func testEscapeCancelsEveryPartialShapeWithoutChangingCompletedElements() {
        for tool in [WireframeTool.rectangle, .circle, .ellipse, .mobileFrame, .browserFrame, .dottedFrame] {
            let model = WireframeCanvasModel()
            model.selectTool(.rectangle)
            model.handleClick(at: CGPoint(x: 10, y: 10))
            model.handleClick(at: CGPoint(x: 90, y: 70))
            model.finishPendingName()
            let original = model.elements
            let revision = model.contentRevision
            model.selectTool(tool)
            model.handleClick(at: CGPoint(x: 100, y: 100))
            if tool == .ellipse {
                model.handleClick(at: CGPoint(x: 200, y: 100))
            }
            XCTAssertTrue(model.handleEscape(), "\(tool)")
            XCTAssertTrue(model.draftPoints.isEmpty)
            XCTAssertEqual(model.elements, original)
            XCTAssertEqual(model.contentRevision, revision)
            XCTAssertEqual(model.selectedTool, tool)
            XCTAssertFalse(model.handleEscape(), "A second Escape can close the board")
        }
    }

    func testEscapeDuringPenStrokeIgnoresRemainingMovementAndMouseUp() {
        let model = WireframeCanvasModel()
        model.selectTool(.pen)
        model.beginPenStroke(at: CGPoint(x: 20, y: 20))
        model.continuePenStroke(at: CGPoint(x: 50, y: 50))
        XCTAssertTrue(model.handleEscape())
        model.continuePenStroke(at: CGPoint(x: 80, y: 80))
        model.endPenStroke(at: CGPoint(x: 100, y: 100))
        XCTAssertTrue(model.elements.isEmpty)
        XCTAssertTrue(model.draftPoints.isEmpty)
        model.beginPenStroke(at: CGPoint(x: 30, y: 30))
        model.endPenStroke(at: CGPoint(x: 60, y: 60))
        XCTAssertEqual(model.elements.count, 1, "A fresh gesture still works")
    }

    func testEscapeCancelsOnlyTheLabelEditAndPreservesTheExistingName() {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        model.handleClick(at: CGPoint(x: 10, y: 10))
        model.handleClick(at: CGPoint(x: 90, y: 70))
        model.namingText = "Original"
        model.finishPendingName()
        let revision = model.contentRevision
        model.selectTool(.rename)
        model.handleClick(at: CGPoint(x: 10, y: 40))
        model.namingText = "Unfinished edit"
        XCTAssertTrue(model.hasUnsavedName)
        XCTAssertTrue(model.handleEscape())
        XCTAssertNil(model.namingElementID)
        XCTAssertEqual(model.elements.first?.name, "Original")
        XCTAssertEqual(model.contentRevision, revision)
        XCTAssertFalse(model.hasUnsavedName)
    }

    func testSavedVersionOpensExactFileAndInvalidatesForEditsThemeOrMissingFile() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiro-wireframe-preview-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        var openedURLs: [URL] = []
        let exporter = WireframeExporter(
            pathWrapper: { .defaultValue }, fileURLProvider: { outputURL },
            openFileInPreview: { openedURLs.append($0) }
        )
        let elements = [WireframeElement(geometry: .rectangle(CGRect(x: 10, y: 10, width: 80, height: 50)))]
        XCTAssertNil(exporter.savedFileURL(revision: 1, colorScheme: .light))
        XCTAssertFalse(exporter.perform(.save, elements: elements, revision: 1, colorScheme: .light).isError)
        XCTAssertEqual(exporter.savedFileURL(revision: 1, colorScheme: .light), outputURL)
        let opened = await exporter.openInPreview(revision: 1, colorScheme: .light)
        XCTAssertFalse(opened.isError)
        XCTAssertEqual(openedURLs, [outputURL])
        XCTAssertNil(exporter.savedFileURL(revision: 2, colorScheme: .light))
        XCTAssertNil(exporter.savedFileURL(revision: 1, colorScheme: .dark))
        try FileManager.default.removeItem(at: outputURL)
        XCTAssertNil(exporter.savedFileURL(revision: 1, colorScheme: .light))
        let missing = await exporter.openInPreview(revision: 1, colorScheme: .light)
        XCTAssertTrue(missing.isError)
        XCTAssertEqual(openedURLs.count, 1)
    }

    func testFailedSaveDoesNotOfferOpenAndPreviewFailureKeepsSavedImage() async {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiro-wireframe-failure-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let elements = [WireframeElement(geometry: .rectangle(CGRect(x: 10, y: 10, width: 80, height: 50)))]
        let failingExporter = WireframeExporter(
            pathWrapper: { .defaultValue },
            fileURLProvider: { throw CocoaError(.fileWriteNoPermission) }
        )
        XCTAssertTrue(failingExporter.perform(.save, elements: elements, revision: 1, colorScheme: .light).isError)
        XCTAssertNil(failingExporter.savedFileURL(revision: 1, colorScheme: .light))
        let exporter = WireframeExporter(
            pathWrapper: { .defaultValue }, fileURLProvider: { outputURL },
            openFileInPreview: { _ in throw CocoaError(.fileReadUnknown) }
        )
        XCTAssertFalse(exporter.perform(.save, elements: elements, revision: 1, colorScheme: .light).isError)
        let result = await exporter.openInPreview(revision: 1, colorScheme: .light)
        XCTAssertTrue(result.isError)
        XCTAssertEqual(exporter.savedFileURL(revision: 1, colorScheme: .light), outputURL)
    }

    func testSelectedInkSurvivesNamingRecoloringAndExport() {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        model.selectColor(.blue)
        model.handleClick(at: CGPoint(x: 30, y: 40))
        model.handleClick(at: CGPoint(x: 120, y: 100))
        XCTAssertEqual(model.elements.first?.color, .blue)

        model.namingText = "Search"
        let revision = model.contentRevision
        model.selectColor(.violet)
        XCTAssertEqual(model.elements.first?.name, "Search")
        XCTAssertEqual(model.elements.first?.color, .violet)
        XCTAssertGreaterThan(model.contentRevision, revision)
        XCTAssertNil(model.namingElementID)
        XCTAssertEqual(
            WireframeExportLayout(elements: model.elements).translatedElements.first?.color,
            .violet
        )
    }

    func testAllFourInksContrastWithBothCanvasThemes() throws {
        func luminance(_ color: Color) throws -> Double {
            let rgb = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
            let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
                .map { value in
                    value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
                }
            return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        }

        for scheme in [ColorScheme.light, .dark] {
            let paper = try luminance(VoiceTypePalette(scheme).surface)
            for ink in WireframeColor.allCases {
                let stroke = try luminance(ink.color(in: scheme))
                let contrast = (max(paper, stroke) + 0.05) / (min(paper, stroke) + 0.05)
                XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(ink) in \(scheme)")
            }
        }
    }

    func testCompletedShapeImmediatelyStartsNamingAndSavesColoredLabelText() {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)

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
        model.selectTool(.rectangle)
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
        model.selectTool(.rectangle)
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
        model.selectTool(.rectangle)
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
        model.selectTool(.rectangle)
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
        model.selectTool(.rectangle)
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
