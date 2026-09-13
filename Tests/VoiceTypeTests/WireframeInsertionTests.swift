import AppKit
import SwiftUI
import XCTest
@testable import VoiceType

final class WireframeCanvasLayoutTests: XCTestCase {
    func testScreenshotsKeepAspectRatioAndFitWithinThreeQuartersOfCanvas() throws {
        let canvas = CGSize(width: 400, height: 400)
        for image in [CGSize(width: 1920, height: 1080), CGSize(width: 390, height: 844), CGSize(width: 1000, height: 1000)] {
            let frame = try XCTUnwrap(WireframeScreenshotLayout.frame(imageSize: image, canvasSize: canvas))
            XCTAssertLessThanOrEqual(frame.width, canvas.width * 0.75)
            XCTAssertLessThanOrEqual(frame.height, canvas.height * 0.75)
            XCTAssertEqual(frame.width / frame.height, image.width / image.height, accuracy: 0.001)
            XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(frame))
            XCTAssertGreaterThanOrEqual(frame.minY, 138)
        }
        XCTAssertNil(WireframeScreenshotLayout.frame(imageSize: .zero, canvasSize: canvas))
    }

    func testCursorHintAvoidsLabelsAndScreenEdges() throws {
        let canvas = CGRect(x: 0, y: 0, width: 400, height: 400)
        let label = CGRect(x: 200, y: 200, width: 130, height: 30)
        for pointer in [CGPoint(x: 190, y: 190), CGPoint(x: 390, y: 390), CGPoint(x: 10, y: 10)] {
            let frame = try XCTUnwrap(WireframeCursorHintLayout.frame(
                pointer: pointer, size: CGSize(width: 125, height: 25), canvas: canvas, avoiding: [label]
            ))
            XCTAssertTrue(canvas.contains(frame))
            XCTAssertFalse(frame.intersects(label.insetBy(dx: -5, dy: -5)))
            XCTAssertFalse(frame.contains(pointer))
        }
        XCTAssertNil(WireframeCursorHintLayout.frame(
            pointer: CGPoint(x: 200, y: 200), size: CGSize(width: 125, height: 25),
            canvas: canvas, avoiding: [canvas]
        ), "Hide the hint when there is no clear nearby space")
    }

    func testScreenshotLookupExcludesExportsAndOtherFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(try ScreenshotStorage.latestScreenshotURL(in: directory))
        let old = directory.appendingPathComponent("Tiro Screenshot 2026-09-10 at 10.00.00.000.png")
        let latest = directory.appendingPathComponent("Tiro Screenshot 2026-09-11 at 10.00.00.000.png")
        let export = directory.appendingPathComponent("Tiro Wireframe 2026-09-12 at 10.00.00.000.png")
        for (index, url) in [old, latest, export, directory.appendingPathComponent("other.png")].enumerated() {
            try Data([0]).write(to: url)
            try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: Double(index + 100))], ofItemAtPath: url.path)
        }
        XCTAssertEqual(try ScreenshotStorage.latestScreenshotURL(in: directory)?.resolvingSymlinksInPath(), latest.resolvingSymlinksInPath())
        try FileManager.default.removeItem(at: latest)
        XCTAssertEqual(try ScreenshotStorage.latestScreenshotURL(in: directory)?.resolvingSymlinksInPath(), old.resolvingSymlinksInPath())
    }
}

@MainActor
final class WireframeInsertionTests: XCTestCase {
    private func sampleImage() -> NSImage {
        NSImage(size: CGSize(width: 100, height: 80), flipped: false) { rect in
            NSColor(srgbRed: 0.1, green: 0.3, blue: 0.9, alpha: 1).setFill()
            NSBezierPath(rect: rect).fill()
            return true
        }
    }

    func testInsertionPreservesDrawingAndUndoOnlyRemovesInsertedScreenshot() {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        model.handleClick(at: CGPoint(x: 100, y: 160))
        model.handleClick(at: CGPoint(x: 200, y: 240))
        model.namingText = "Existing shape"
        let originalID = model.elements[0].id
        model.insertScreenshot(sampleImage(), canvasSize: CGSize(width: 400, height: 400))
        XCTAssertEqual(model.elements.count, 2)
        XCTAssertEqual(model.elements[0].id, originalID)
        XCTAssertEqual(model.elements[0].name, "Existing shape")
        XCTAssertNotNil(model.elements[1].image)
        XCTAssertNil(model.namingElementID)
        model.undoLast()
        XCTAssertEqual(model.elements.count, 1)
        XCTAssertEqual(model.elements[0].id, originalID)
    }

    func testImageAndSubsequentDrawingBothAppearInExport() throws {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        model.insertScreenshot(sampleImage(), canvasSize: CGSize(width: 400, height: 400))
        let imageBounds = model.elements[0].geometry.bounds
        model.handleClick(at: CGPoint(x: imageBounds.minX + 10, y: imageBounds.minY + 10))
        model.handleClick(at: CGPoint(x: imageBounds.minX + 30, y: imageBounds.minY + 30))
        model.finishPendingName()
        XCTAssertEqual(model.elements.count, 2)
        let layout = WireframeExportLayout(elements: model.elements)
        XCTAssertNotNil(layout.translatedElements[0].image)
        XCTAssertTrue(layout.sourceRect.contains(imageBounds))
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("wireframe-image-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output) }
        let exporter = WireframeExporter(pathWrapper: { .defaultValue }, fileURLProvider: { output })
        XCTAssertFalse(exporter.perform(.save, elements: model.elements, revision: model.contentRevision, colorScheme: .light).isError)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: output)))
        let imageRect = layout.translatedElements[0].geometry.bounds
        let center = try XCTUnwrap(bitmap.colorAt(x: Int(imageRect.midX * 2), y: Int(imageRect.midY * 2))?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(center.blueComponent, 0.8, "Screenshot pixels must be present")
        let border = try XCTUnwrap(bitmap.colorAt(x: Int((imageRect.minX + 10) * 2), y: Int((imageRect.minY + 20) * 2))?.usingColorSpace(.sRGB))
        XCTAssertLessThan(border.blueComponent, 0.3, "Drawing must render above the screenshot")
        model.clearAll()
        XCTAssertTrue(model.elements.isEmpty)
    }

    func testCursorHintsAdvanceWithDrawingAndHideWhileNaming() {
        let model = WireframeCanvasModel()
        model.selectTool(.rectangle)
        XCTAssertEqual(model.cursorHint, "Click first point")
        model.handleClick(at: CGPoint(x: 100, y: 150))
        XCTAssertEqual(model.cursorHint, "Click second point")
        model.handleClick(at: CGPoint(x: 200, y: 240))
        XCTAssertNil(model.cursorHint)
        model.finishPendingName()
        model.selectTool(.ellipse)
        model.handleClick(at: CGPoint(x: 100, y: 150))
        XCTAssertEqual(model.cursorHint, "Click axis end")
        model.handleClick(at: CGPoint(x: 200, y: 150))
        XCTAssertEqual(model.cursorHint, "Click width")
        model.handleEscape()
        XCTAssertEqual(model.cursorHint, "Click first point")
        model.selectTool(.rename)
        XCTAssertEqual(model.cursorHint, "Click border to label")
    }
}
