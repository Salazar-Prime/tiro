import AppKit
import Carbon

@MainActor
final class HotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pasteHotKey: GlobalHotKey?
    private var comboIsDown = false
    private var gestureMachine = VoiceGestureMachine()
    private var finishTimer: Timer?
    private let onVoiceAction: (VoiceGestureAction) -> Void
    private let onPaste: () -> Void

    init(
        onVoiceAction: @escaping (VoiceGestureAction) -> Void,
        onPaste: @escaping () -> Void
    ) {
        self.onVoiceAction = onVoiceAction
        self.onPaste = onPaste
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

        let pasteHotKey = GlobalHotKey(
            identifier: 1,
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | controlKey),
            action: onPaste
        )
        _ = pasteHotKey.register()
        self.pasteHotKey = pasteHotKey
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
        pasteHotKey?.unregister()
        pasteHotKey = nil
        finishTimer?.invalidate()
        finishTimer = nil
        gestureMachine.reset()
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            handleFlags(event.modifierFlags)
        }
    }

    private func handleFlags(_ rawFlags: NSEvent.ModifierFlags) {
        let flags = rawFlags.intersection(.deviceIndependentFlagsMask)
        let isDown = flags.contains(.control) && flags.contains(.option)
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
