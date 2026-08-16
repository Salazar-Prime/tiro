import Carbon
import XCTest
@testable import VoiceType

final class ShortcutConfigurationTests: XCTestCase {
    func testDefaultsMatchDocumentedShortcuts() {
        let configuration = ShortcutConfiguration.defaults

        XCTAssertEqual(configuration.voiceTyping.displayName, "⌃⌥")
        XCTAssertEqual(configuration.pasteLast?.displayName, "⌃⌘V")
        XCTAssertNil(configuration.openHistory)
        XCTAssertNil(configuration.captureScreen)
        XCTAssertEqual(configuration.captureSelection?.displayName, "⇧⌘2")
        XCTAssertEqual(configuration.attachScreenshot?.displayName, "S")
        XCTAssertNoThrow(try configuration.validate())
    }

    func testConfigurationRoundTripsThroughJSON() throws {
        var configuration = ShortcutConfiguration.defaults
        try configuration.set(
            .key(kVK_ANSI_R, label: "R", modifiers: UInt32(optionKey | cmdKey)),
            for: .captureScreen
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(ShortcutConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.captureScreen?.displayName, "⌥⌘R")
    }

    func testDuplicateShortcutIsRejectedEvenWhenLabelsDiffer() {
        var configuration = ShortcutConfiguration.defaults
        let original = configuration
        let duplicate = TiroShortcut(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(controlKey | cmdKey),
            keyLabel: "Different label"
        )

        XCTAssertThrowsError(try configuration.set(duplicate, for: .captureScreen)) { error in
            XCTAssertEqual(
                error as? ShortcutConfigurationError,
                .conflict(.pasteLast, .captureScreen)
            )
        }
        XCTAssertEqual(configuration, original)
    }

    func testModifierOnlyVoiceShortcutRequiresTwoModifiers() {
        var configuration = ShortcutConfiguration.defaults

        XCTAssertThrowsError(
            try configuration.set(
                .modifierChord(UInt32(optionKey)),
                for: .voiceTyping
            )
        ) { error in
            XCTAssertEqual(
                error as? ShortcutConfigurationError,
                .voiceNeedsTwoModifiers
            )
        }
    }

    func testVoiceShortcutMayUseOneModifierAndAKey() throws {
        var configuration = ShortcutConfiguration.defaults

        try configuration.set(
            .key(kVK_ANSI_D, label: "D", modifiers: UInt32(optionKey)),
            for: .voiceTyping
        )

        XCTAssertEqual(configuration.voiceTyping.displayName, "⌥D")
    }

    func testChangingVoiceShortcutKeepsAttachmentAsSingleKey() throws {
        var configuration = ShortcutConfiguration.defaults

        try configuration.set(
            .modifierChord(UInt32(optionKey | cmdKey)),
            for: .voiceTyping
        )

        XCTAssertEqual(configuration.voiceTyping.displayName, "⌥⌘")
        XCTAssertEqual(configuration.attachScreenshot?.displayName, "S")
    }

    func testAttachmentRouteAcceptsOneUnmodifiedKey() throws {
        var configuration = ShortcutConfiguration.defaults

        try configuration.set(
            .key(kVK_ANSI_K, label: "K", modifiers: 0),
            for: .attachScreenshot
        )

        XCTAssertEqual(configuration.attachScreenshot?.displayName, "K")
    }

    func testAttachmentRouteRejectsModifierCombination() {
        var configuration = ShortcutConfiguration.defaults

        XCTAssertThrowsError(
            try configuration.set(
                .key(kVK_ANSI_K, label: "K", modifiers: UInt32(optionKey)),
                for: .attachScreenshot
            )
        ) { error in
            XCTAssertEqual(
                error as? ShortcutConfigurationError,
                .attachmentNeedsSingleKey
            )
        }
    }

    func testNormalizesLegacyAttachmentCombinationWithoutChangingOtherRoutes() {
        var configuration = ShortcutConfiguration.defaults
        configuration.attachScreenshot = .key(
            kVK_ANSI_K,
            label: "K",
            modifiers: UInt32(controlKey | optionKey)
        )
        let pasteShortcut = configuration.pasteLast

        configuration.normalizeContextShortcuts()

        XCTAssertEqual(configuration.attachScreenshot?.displayName, "K")
        XCTAssertEqual(configuration.pasteLast, pasteShortcut)
        XCTAssertNoThrow(try configuration.validate())
    }

    func testOptionalRouteCanBeCleared() throws {
        var configuration = ShortcutConfiguration.defaults

        try configuration.set(nil, for: .pasteLast)

        XCTAssertNil(configuration.pasteLast)
        XCTAssertNoThrow(try configuration.validate())
    }

    func testHistoryRouteCanBeAssigned() throws {
        var configuration = ShortcutConfiguration.defaults

        try configuration.set(
            .key(kVK_ANSI_H, label: "H", modifiers: UInt32(optionKey | cmdKey)),
            for: .openHistory
        )

        XCTAssertEqual(configuration.openHistory?.displayName, "⌥⌘H")
        XCTAssertNoThrow(try configuration.validate())
    }

    func testDecodesConfigurationSavedBeforeHistoryRouteExisted() throws {
        let current = ShortcutConfiguration.defaults
        let legacy = LegacyShortcutConfiguration(
            voiceTyping: current.voiceTyping,
            pasteLast: current.pasteLast,
            captureScreen: current.captureScreen,
            captureSelection: current.captureSelection,
            attachScreenshot: current.attachScreenshot
        )

        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(ShortcutConfiguration.self, from: data)

        XCTAssertNil(decoded.openHistory)
        XCTAssertEqual(decoded.voiceTyping, current.voiceTyping)
    }
}

private struct LegacyShortcutConfiguration: Encodable {
    let voiceTyping: TiroShortcut
    let pasteLast: TiroShortcut?
    let captureScreen: TiroShortcut?
    let captureSelection: TiroShortcut?
    let attachScreenshot: TiroShortcut?
}
