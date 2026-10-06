import Foundation
import XCTest
@testable import VoiceType

@MainActor
final class TextInsertionServiceTests: XCTestCase {
    func testElectronEditorsUsePasteForBothPackagedAndDevelopmentApps() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        for (name, identifier) in [
            ("PanePilot", "com.salazarprime.panepilot"),
            ("Electron", "com.github.Electron"),
            ("Renamed editor", "example.custom-editor")
        ] {
            let bundle = directory.appendingPathComponent("\(name).app")
            try FileManager.default.createDirectory(
                at: bundle.appendingPathComponent("Contents/Frameworks/Electron Framework.framework"),
                withIntermediateDirectories: true
            )
            XCTAssertTrue(TextInsertionService.prefersPasteCommand(
                bundleIdentifier: identifier,
                bundleURL: bundle
            ))
        }
    }

    func testNativeEditorsKeepDirectInsertionAndBrowsersKeepPaste() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nativeBundle = directory.appendingPathComponent("Native editor.app")
        try FileManager.default.createDirectory(at: nativeBundle, withIntermediateDirectories: true)

        XCTAssertFalse(TextInsertionService.prefersPasteCommand(
            bundleIdentifier: "com.apple.TextEdit", bundleURL: nativeBundle
        ))
        XCTAssertFalse(TextInsertionService.prefersPasteCommand(bundleIdentifier: nil, bundleURL: nil))
        XCTAssertTrue(TextInsertionService.prefersPasteCommand(
            bundleIdentifier: "com.apple.Safari", bundleURL: nil
        ))
        XCTAssertTrue(TextInsertionService.prefersPasteCommand(
            bundleIdentifier: "com.google.Chrome", bundleURL: nil
        ))
    }

    func testAFileNamedLikeTheFrameworkDoesNotIdentifyAnElectronApp() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: bundle) }
        let frameworks = bundle.appendingPathComponent("Contents/Frameworks")
        try FileManager.default.createDirectory(at: frameworks, withIntermediateDirectories: true)
        try Data().write(to: frameworks.appendingPathComponent("Electron Framework.framework"))

        XCTAssertFalse(TextInsertionService.prefersPasteCommand(
            bundleIdentifier: "example.native-editor", bundleURL: bundle
        ))
    }
}
