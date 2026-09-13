import AppKit
import Carbon
import Foundation

enum ShortcutAction: String, CaseIterable, Identifiable {
    case voiceTyping
    case openWireframe
    case pasteLast
    case openHistory
    case captureScreen
    case captureSelection
    case attachScreenshot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voiceTyping: "Voice typing"
        case .openWireframe: "Open Wireframe Board"
        case .pasteLast: "Paste last capture"
        case .openHistory: "Open transcript history"
        case .captureScreen: "Capture visible screen"
        case .captureSelection: "Capture selection"
        case .attachScreenshot: "Attach while speaking"
        }
    }

    var allowsClearing: Bool {
        self != .voiceTyping && self != .openWireframe
    }

    var usesSingleContextKey: Bool {
        self == .attachScreenshot
    }
}

struct TiroShortcut: Codable, Equatable, Hashable {
    static let relevantCarbonModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    let keyCode: UInt32?
    let modifiers: UInt32
    let keyLabel: String?

    init(keyCode: UInt32?, modifiers: UInt32, keyLabel: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.relevantCarbonModifiers
        self.keyLabel = keyLabel
    }

    static func == (lhs: TiroShortcut, rhs: TiroShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }

    static func modifierChord(_ modifiers: UInt32) -> TiroShortcut {
        TiroShortcut(keyCode: nil, modifiers: modifiers)
    }

    static func key(_ keyCode: Int, label: String, modifiers: UInt32) -> TiroShortcut {
        TiroShortcut(
            keyCode: UInt32(keyCode),
            modifiers: modifiers,
            keyLabel: label
        )
    }

    var displayName: String {
        displayTokens.joined()
    }

    var displayTokens: [String] {
        var tokens: [String] = []
        if modifiers & UInt32(controlKey) != 0 { tokens.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { tokens.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { tokens.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { tokens.append("⌘") }
        if let keyLabel { tokens.append(keyLabel) }
        return tokens
    }

    var modifierCount: Int {
        [controlKey, optionKey, shiftKey, cmdKey]
            .count { modifiers & UInt32($0) != 0 }
    }

    var eventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    var menuKeyEquivalent: String? {
        guard keyCode != nil, let keyLabel else { return nil }
        if keyLabel.count == 1 {
            return keyLabel.lowercased()
        }
        if keyLabel == "Space" { return " " }
        return nil
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    static func keyLabel(for event: NSEvent) -> String {
        let specialLabels: [Int: String] = [
            kVK_Space: "Space",
            kVK_Return: "Return",
            kVK_Tab: "Tab",
            kVK_Delete: "Delete",
            kVK_ForwardDelete: "Forward Delete",
            kVK_Home: "Home",
            kVK_End: "End",
            kVK_PageUp: "Page Up",
            kVK_PageDown: "Page Down",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
            kVK_F1: "F1",
            kVK_F2: "F2",
            kVK_F3: "F3",
            kVK_F4: "F4",
            kVK_F5: "F5",
            kVK_F6: "F6",
            kVK_F7: "F7",
            kVK_F8: "F8",
            kVK_F9: "F9",
            kVK_F10: "F10",
            kVK_F11: "F11",
            kVK_F12: "F12",
            kVK_F13: "F13",
            kVK_F14: "F14",
            kVK_F15: "F15",
            kVK_F16: "F16",
            kVK_F17: "F17",
            kVK_F18: "F18",
            kVK_F19: "F19",
            kVK_F20: "F20"
        ]
        if let specialLabel = specialLabels[Int(event.keyCode)] {
            return specialLabel
        }

        let characters = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return characters?.isEmpty == false ? characters ?? "" : "Key \(event.keyCode)"
    }
}

struct ShortcutConfiguration: Codable, Equatable {
    var voiceTyping: TiroShortcut
    var openWireframe: TiroShortcut?
    var pasteLast: TiroShortcut?
    var openHistory: TiroShortcut?
    var captureScreen: TiroShortcut?
    var captureSelection: TiroShortcut?
    var attachScreenshot: TiroShortcut?

    static let defaults = ShortcutConfiguration(
        voiceTyping: .modifierChord(UInt32(controlKey | optionKey)),
        openWireframe: .key(
            kVK_ANSI_W,
            label: "W",
            modifiers: UInt32(controlKey | optionKey)
        ),
        pasteLast: .key(kVK_ANSI_V, label: "V", modifiers: UInt32(controlKey | cmdKey)),
        openHistory: nil,
        captureScreen: nil,
        captureSelection: .key(kVK_ANSI_2, label: "2", modifiers: UInt32(cmdKey | shiftKey)),
        attachScreenshot: .key(kVK_ANSI_S, label: "S", modifiers: 0)
    )

    func shortcut(for action: ShortcutAction) -> TiroShortcut? {
        switch action {
        case .voiceTyping: voiceTyping
        case .openWireframe: openWireframe
        case .pasteLast: pasteLast
        case .openHistory: openHistory
        case .captureScreen: captureScreen
        case .captureSelection: captureSelection
        case .attachScreenshot: attachScreenshot
        }
    }

    mutating func normalizeContextShortcuts() {
        guard let attachment = attachScreenshot,
              attachment.modifiers != 0
        else { return }
        attachScreenshot = TiroShortcut(
            keyCode: attachment.keyCode,
            modifiers: 0,
            keyLabel: attachment.keyLabel
        )
    }

    mutating func restoreMissingWireframeShortcutIfAvailable() {
        guard openWireframe == nil,
              let defaultShortcut = Self.defaults.openWireframe
        else { return }
        let isAlreadyUsed = ShortcutAction.allCases
            .filter { $0 != .openWireframe }
            .contains { shortcut(for: $0) == defaultShortcut }
        if !isAlreadyUsed {
            openWireframe = defaultShortcut
        }
    }

    func shouldCancelModifierVoiceActivation(for shortcut: TiroShortcut) -> Bool {
        voiceTyping.keyCode == nil
            && shortcut.modifiers & voiceTyping.modifiers == voiceTyping.modifiers
    }

    mutating func set(_ shortcut: TiroShortcut?, for action: ShortcutAction) throws {
        var updated = self
        switch action {
        case .voiceTyping:
            guard let shortcut else { throw ShortcutConfigurationError.voiceRequired }
            updated.voiceTyping = shortcut
        case .openWireframe:
            guard let shortcut else { throw ShortcutConfigurationError.wireframeRequired }
            updated.openWireframe = shortcut
        case .pasteLast:
            updated.pasteLast = shortcut
        case .openHistory:
            updated.openHistory = shortcut
        case .captureScreen:
            updated.captureScreen = shortcut
        case .captureSelection:
            updated.captureSelection = shortcut
        case .attachScreenshot:
            updated.attachScreenshot = shortcut
        }
        try updated.validate()
        self = updated
    }

    func validate() throws {
        if voiceTyping.keyCode == nil {
            guard voiceTyping.modifierCount >= 2 else {
                throw ShortcutConfigurationError.voiceNeedsTwoModifiers
            }
        } else if voiceTyping.modifiers == 0 {
            throw ShortcutConfigurationError.shortcutNeedsModifier
        }

        let keyActions = ShortcutAction.allCases.filter { $0 != .voiceTyping }
        for action in keyActions {
            guard let shortcut = shortcut(for: action) else { continue }
            guard shortcut.keyCode != nil else {
                throw ShortcutConfigurationError.actionNeedsKey(action)
            }
            if action.usesSingleContextKey {
                guard shortcut.modifiers == 0 else {
                    throw ShortcutConfigurationError.attachmentNeedsSingleKey
                }
            } else if shortcut.modifiers == 0 {
                throw ShortcutConfigurationError.shortcutNeedsModifier
            }
        }

        var assigned: [TiroShortcut: ShortcutAction] = [:]
        for action in ShortcutAction.allCases {
            guard let shortcut = shortcut(for: action), shortcut.keyCode != nil else { continue }
            if let existing = assigned[shortcut] {
                throw ShortcutConfigurationError.conflict(existing, action)
            }
            assigned[shortcut] = action
        }
    }
}

enum ShortcutConfigurationError: LocalizedError, Equatable {
    case voiceRequired
    case wireframeRequired
    case voiceNeedsTwoModifiers
    case shortcutNeedsModifier
    case attachmentNeedsSingleKey
    case actionNeedsKey(ShortcutAction)
    case conflict(ShortcutAction, ShortcutAction)

    var errorDescription: String? {
        switch self {
        case .voiceRequired:
            "Voice typing must have a shortcut."
        case .wireframeRequired:
            "Wireframe Board must have a shortcut."
        case .voiceNeedsTwoModifiers:
            "Use at least two modifiers, or one modifier with a key, for voice typing."
        case .shortcutNeedsModifier:
            "Include Command, Option, Control, or Shift with the key."
        case .attachmentNeedsSingleKey:
            "Attach while speaking uses one key without modifiers."
        case let .actionNeedsKey(action):
            action.usesSingleContextKey
                ? "\(action.title) needs one regular key."
                : "\(action.title) needs a regular key as well as a modifier."
        case let .conflict(first, second):
            "That shortcut is already used by \(first.title.lowercased()) and \(second.title.lowercased())."
        }
    }
}
