import AppKit
import Carbon
import SwiftUI

@MainActor
final class ShortcutRecordingSession: ObservableObject {
    @Published private(set) var activeAction: ShortcutAction?
    @Published private(set) var guidance = ""

    private var monitor: Any?
    private var largestModifierChord: UInt32 = 0
    private var capture: ((TiroShortcut?) -> Void)?
    private var recordingStateChanged: ((Bool) -> Void)?

    func begin(action: ShortcutAction, model: AppModel) {
        if activeAction == action {
            cancel()
            return
        }

        stopMonitoring(notify: activeAction != nil)
        activeAction = action
        if action == .voiceTyping {
            guidance = "Hold a modifier chord, or press modifiers with a key"
        } else if action.usesSingleContextKey {
            guidance = "Press one key — it only works while voice typing"
        } else {
            guidance = "Press modifiers with a key"
        }
        largestModifierChord = 0
        capture = { [weak model] shortcut in
            model?.setShortcut(shortcut, for: action)
        }
        recordingStateChanged = { [weak model] isActive in
            model?.setShortcutRecordingActive(isActive)
        }
        recordingStateChanged?(true)

        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            var wasConsumed = false
            MainActor.assumeIsolated {
                wasConsumed = self?.handle(event) == nil
            }
            return wasConsumed ? nil : event
        }
    }

    func cancel() {
        stopMonitoring(notify: true)
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let action = activeAction else { return event }

        if event.type == .flagsChanged {
            guard action == .voiceTyping else { return event }
            let modifiers = TiroShortcut.carbonModifiers(from: event.modifierFlags)
            let count = TiroShortcut.modifierChord(modifiers).modifierCount
            let largestCount = TiroShortcut.modifierChord(largestModifierChord).modifierCount
            if count > largestCount {
                largestModifierChord = modifiers
            }

            if modifiers == 0 {
                if largestCount >= 2 {
                    finish(with: .modifierChord(largestModifierChord))
                } else if largestModifierChord != 0 {
                    guidance = "Use at least two modifiers for a modifier-only shortcut"
                    largestModifierChord = 0
                }
            }
            return nil
        }

        guard event.type == .keyDown, !event.isARepeat else { return nil }
        if Int(event.keyCode) == kVK_Escape {
            cancel()
            return nil
        }
        if action.allowsClearing,
           [kVK_Delete, kVK_ForwardDelete].contains(Int(event.keyCode)) {
            finish(with: nil)
            return nil
        }

        let modifiers = TiroShortcut.carbonModifiers(from: event.modifierFlags)
        if action.usesSingleContextKey {
            finish(
                with: TiroShortcut(
                    keyCode: UInt32(event.keyCode),
                    modifiers: 0,
                    keyLabel: TiroShortcut.keyLabel(for: event)
                )
            )
            return nil
        }
        guard modifiers != 0 else {
            guidance = "Add Command, Option, Control, or Shift"
            return nil
        }

        finish(
            with: TiroShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: modifiers,
                keyLabel: TiroShortcut.keyLabel(for: event)
            )
        )
        return nil
    }

    private func finish(with shortcut: TiroShortcut?) {
        let capture = capture
        stopMonitoring(notify: false)
        capture?(shortcut)
        recordingStateChanged?(false)
        recordingStateChanged = nil
    }

    private func stopMonitoring(notify: Bool) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        activeAction = nil
        guidance = ""
        largestModifierChord = 0
        capture = nil
        if notify {
            recordingStateChanged?(false)
            recordingStateChanged = nil
        }
    }
}

struct ShortcutSettingsSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: ShortcutRecordingSession
    let palette: VoiceTypePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("KEY ROUTING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(palette.ink.opacity(0.54))
                Spacer()
                Button("Reset defaults") {
                    recorder.cancel()
                    model.resetShortcuts()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.coral)
            }

            VStack(spacing: 0) {
                ForEach(Array(ShortcutAction.allCases.enumerated()), id: \.element.id) { index, action in
                    ShortcutRouteRow(
                        action: action,
                        model: model,
                        recorder: recorder,
                        palette: palette
                    )
                    if index < ShortcutAction.allCases.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }

            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(recorder.activeAction == nil ? palette.aqua : palette.coral)
                    .frame(width: 7, height: 7)
                    .padding(.top, 3)
                Text(helperText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if let message = model.shortcutMessage {
                Text(message)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(
                        message == "Shortcuts updated." || message == "Default shortcuts restored."
                            ? palette.aqua
                            : palette.danger
                    )
            }
        }
    }

    private var helperText: String {
        if recorder.activeAction != nil {
            return "\(recorder.guidance). Press Escape to cancel."
        }
        return "Click a route, then press its new shortcut. Voice typing also accepts a modifier-only chord."
    }
}

private struct ShortcutRouteRow: View {
    let action: ShortcutAction
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: ShortcutRecordingSession
    let palette: VoiceTypePalette

    private var shortcut: TiroShortcut? {
        model.shortcutConfiguration.shortcut(for: action)
    }

    private var isRecording: Bool {
        recorder.activeAction == action
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(action.tint(palette).opacity(0.14))
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(action.tint(palette))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink)
                Text(action.detail)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if action.allowsClearing, shortcut != nil, !isRecording {
                Button {
                    model.setShortcut(nil, for: action)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(palette.ink.opacity(0.45))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Remove \(action.title.lowercased()) shortcut")
            }

            Button {
                recorder.begin(action: action, model: model)
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        Circle()
                            .fill(palette.coral)
                            .frame(width: 6, height: 6)
                        Text("PRESS KEYS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.35)
                    } else if let shortcut {
                        ForEach(Array(shortcut.displayTokens.enumerated()), id: \.offset) { _, token in
                            Text(token)
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .frame(minWidth: 17, minHeight: 19)
                                .background(palette.surface, in: RoundedRectangle(cornerRadius: 4))
                        }
                    } else {
                        Text("SET")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                    }
                }
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 9)
                .frame(minWidth: 96, minHeight: 30)
                .background(
                    isRecording ? palette.coral.opacity(0.14) : palette.field,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isRecording ? palette.coral.opacity(0.56) : palette.stroke,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Cancel recording" : "Change \(action.title.lowercased()) shortcut")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
    }
}

private extension ShortcutAction {
    var icon: String {
        switch self {
        case .voiceTyping: "waveform.and.mic"
        case .openWireframe: "square.grid.3x3"
        case .pasteLast: "text.cursor"
        case .openHistory: "clock.arrow.circlepath"
        case .captureScreen: "rectangle.inset.filled"
        case .captureSelection: "viewfinder"
        case .attachScreenshot: "camera.badge.clock"
        }
    }

    var detail: String {
        switch self {
        case .voiceTyping: "Hold to speak · double-tap to lock"
        case .openWireframe: "Open the sketching canvas from anywhere"
        case .pasteLast: "Insert the newest transcript or screenshot path"
        case .openHistory: "Open the History page from anywhere"
        case .captureScreen: "Everything except the menu bar and Dock"
        case .captureSelection: "Drag to frame an area"
        case .attachScreenshot: "One key, active only while the mic is listening"
        }
    }

    func tint(_ palette: VoiceTypePalette) -> Color {
        switch self {
        case .voiceTyping, .captureSelection, .attachScreenshot: palette.coral
        case .openWireframe, .pasteLast, .openHistory, .captureScreen: palette.aqua
        }
    }
}
