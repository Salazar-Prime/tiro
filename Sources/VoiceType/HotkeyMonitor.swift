import AppKit
import Carbon

@MainActor
final class HotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var registeredHotKeys: [GlobalHotKey] = []
    private var contextualHotKeys: [GlobalHotKey] = []
    private var comboIsDown = false
    private var voiceTypingIsActive = false
    private var attachmentKeyIsDown = false
    private var gestureMachine = VoiceGestureMachine()
    private var finishTimer: Timer?
    private var isPausedForShortcutRecording = false
    private var shortcuts: ShortcutConfiguration
    private let onVoiceAction: (VoiceGestureAction) -> Void
    private let onPaste: () -> Void
    private let onOpenHistory: () -> Void
    private let onScreenshot: () -> Void
    private let onCaptureScreen: () -> Void
    private let onCaptureSelection: () -> Void
    private let onRegistrationFailure: (ShortcutAction) -> Void
    private var lastScreenshotAt = Date.distantPast

    init(
        shortcuts: ShortcutConfiguration,
        onVoiceAction: @escaping (VoiceGestureAction) -> Void,
        onPaste: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void,
        onScreenshot: @escaping () -> Void,
        onCaptureScreen: @escaping () -> Void,
        onCaptureSelection: @escaping () -> Void,
        onRegistrationFailure: @escaping (ShortcutAction) -> Void
    ) {
        self.shortcuts = shortcuts
        self.onVoiceAction = onVoiceAction
        self.onPaste = onPaste
        self.onOpenHistory = onOpenHistory
        self.onScreenshot = onScreenshot
        self.onCaptureScreen = onCaptureScreen
        self.onCaptureSelection = onCaptureSelection
        self.onRegistrationFailure = onRegistrationFailure
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return event
        }

        registerHotKeys()
    }

    func updateShortcuts(_ updated: ShortcutConfiguration) {
        guard shortcuts != updated else { return }
        unregisterHotKeys()
        shortcuts = updated
        if comboIsDown {
            comboIsDown = false
            perform(gestureMachine.comboBecameUp())
        }
        if !isPausedForShortcutRecording,
           globalMonitor != nil || localMonitor != nil {
            registerHotKeys()
        }
    }

    func setPausedForShortcutRecording(_ isPaused: Bool) {
        guard isPausedForShortcutRecording != isPaused else { return }
        isPausedForShortcutRecording = isPaused

        if isPaused {
            unregisterHotKeys()
            if comboIsDown {
                comboIsDown = false
                perform(gestureMachine.comboBecameUp())
            }
        } else if globalMonitor != nil || localMonitor != nil {
            registerHotKeys()
        }
    }

    func setVoiceTypingActive(_ isActive: Bool) {
        guard voiceTypingIsActive != isActive else { return }
        voiceTypingIsActive = isActive
        unregisterContextualHotKeys()

        if isActive,
           !isPausedForShortcutRecording,
           globalMonitor != nil || localMonitor != nil {
            registerAttachmentHotKeys()
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        unregisterHotKeys()
        finishTimer?.invalidate()
        finishTimer = nil
        comboIsDown = false
        voiceTypingIsActive = false
        gestureMachine.reset()
    }

    private func registerHotKeys() {
        guard !isPausedForShortcutRecording else { return }
        register(shortcuts.pasteLast, action: .pasteLast, identifier: 1, press: onPaste)
        register(
            shortcuts.openHistory,
            action: .openHistory,
            identifier: 2,
            press: onOpenHistory
        )
        register(
            shortcuts.captureSelection,
            action: .captureSelection,
            identifier: 4,
            press: onCaptureSelection
        )
        register(
            shortcuts.captureScreen,
            action: .captureScreen,
            identifier: 5,
            press: onCaptureScreen
        )

        if shortcuts.voiceTyping.keyCode != nil {
            register(
                shortcuts.voiceTyping,
                action: .voiceTyping,
                identifier: 6,
                press: { [weak self] in self?.voiceShortcutBecameDown() },
                release: { [weak self] in self?.voiceShortcutBecameUp() }
            )
        }

        if voiceTypingIsActive {
            registerAttachmentHotKeys()
        }
    }

    private func register(
        _ shortcut: TiroShortcut?,
        action: ShortcutAction,
        identifier: UInt32,
        press: @escaping () -> Void,
        release: (() -> Void)? = nil,
        isContextual: Bool = false
    ) {
        guard let shortcut, let keyCode = shortcut.keyCode else { return }
        let hotKey = GlobalHotKey(
            identifier: identifier,
            keyCode: keyCode,
            modifiers: shortcut.modifiers,
            action: press,
            releaseAction: release
        )
        guard hotKey.register() else {
            onRegistrationFailure(action)
            return
        }
        if isContextual {
            contextualHotKeys.append(hotKey)
        } else {
            registeredHotKeys.append(hotKey)
        }
    }

    private func unregisterHotKeys() {
        unregisterContextualHotKeys()
        registeredHotKeys.forEach { $0.unregister() }
        registeredHotKeys.removeAll()
    }

    private func registerAttachmentHotKeys() {
        guard contextualHotKeys.isEmpty,
              voiceTypingIsActive,
              !isPausedForShortcutRecording,
              let attachment = shortcuts.attachScreenshot,
              attachment.keyCode != nil
        else { return }

        let modifierVariants = Set([UInt32(0), shortcuts.voiceTyping.modifiers])
            .sorted()
        for (index, modifiers) in modifierVariants.enumerated() {
            let contextualShortcut = TiroShortcut(
                keyCode: attachment.keyCode,
                modifiers: modifiers,
                keyLabel: attachment.keyLabel
            )
            register(
                contextualShortcut,
                action: .attachScreenshot,
                identifier: UInt32(20 + index),
                press: { [weak self] in self?.handleScreenshotHotKey() },
                release: { [weak self] in self?.attachmentKeyBecameUp() },
                isContextual: true
            )
        }
    }

    private func unregisterContextualHotKeys() {
        contextualHotKeys.forEach { $0.unregister() }
        contextualHotKeys.removeAll()
        attachmentKeyIsDown = false
    }

    private func handleScreenshotHotKey() {
        guard !isPausedForShortcutRecording,
              voiceTypingIsActive,
              !attachmentKeyIsDown
        else { return }
        let now = Date()
        guard now.timeIntervalSince(lastScreenshotAt) >= 0.2 else { return }
        attachmentKeyIsDown = true
        lastScreenshotAt = now
        onScreenshot()
    }

    private func attachmentKeyBecameUp() {
        attachmentKeyIsDown = false
    }

    private func handle(_ event: NSEvent) {
        guard !isPausedForShortcutRecording,
              event.type == .flagsChanged,
              shortcuts.voiceTyping.keyCode == nil
        else { return }

        let currentModifiers = TiroShortcut.carbonModifiers(from: event.modifierFlags)
        let requiredModifiers = shortcuts.voiceTyping.modifiers
        let isDown = currentModifiers & requiredModifiers == requiredModifiers
        updateVoiceShortcutState(isDown: isDown)
    }

    private func voiceShortcutBecameDown() {
        guard !isPausedForShortcutRecording else { return }
        updateVoiceShortcutState(isDown: true)
    }

    private func voiceShortcutBecameUp() {
        guard !isPausedForShortcutRecording else { return }
        updateVoiceShortcutState(isDown: false)
    }

    private func updateVoiceShortcutState(isDown: Bool) {
        guard isDown != comboIsDown else { return }
        comboIsDown = isDown
        perform(isDown ? gestureMachine.comboBecameDown() : gestureMachine.comboBecameUp())
    }

    private func perform(_ actions: [VoiceGestureAction]) {
        for action in actions {
            switch action {
            case let .scheduleFinish(delay):
                finishTimer?.invalidate()
                finishTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
                    [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.finishTimer = nil
                        self.perform(self.gestureMachine.scheduledFinishFired())
                    }
                }
            case .cancelScheduledFinish:
                finishTimer?.invalidate()
                finishTimer = nil
            default:
                onVoiceAction(action)
            }
        }
    }
}
