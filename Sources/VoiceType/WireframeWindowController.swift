import AppKit
import SwiftUI

@MainActor
final class WireframeWindowController: NSObject, NSWindowDelegate {
    private let model: WireframeCanvasModel
    private let exporter: WireframeExporter
    private let panel: WireframePanel
    private let onDismiss: () -> Void
    private var isDismissing = false
    private let presentation = WireframePresentation()
    private var transitionTask: Task<Void, Never>?

    var isVisible: Bool {
        panel.isVisible
    }

    init(
        pathWrapper: @escaping () -> ScreenshotPathWrapper,
        onDismiss: @escaping () -> Void
    ) {
        let model = WireframeCanvasModel()
        let exporter = WireframeExporter(
            pathWrapper: pathWrapper
        )
        self.model = model
        self.exporter = exporter
        self.onDismiss = onDismiss
        panel = WireframePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.onEscape = { [weak self] in
            guard let self else { return }
            if !model.handleEscape() { dismiss() }
        }

        panel.delegate = self
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.sharingType = .readOnly
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        panel.contentView = NSHostingView(
            rootView: WireframePresentationView(
                presentation: presentation,
                content: WireframeBoardView(
                    model: model,
                    exporter: exporter,
                    onClose: { [weak self] in self?.dismiss() }
                )
            )
        )
    }

    func show() {
        if panel.isVisible, !isDismissing {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let wasDismissing = isDismissing
        transitionTask?.cancel()
        isDismissing = false
        panel.ignoresMouseEvents = false
        presentation.reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let visibleFrame = activeScreen().visibleFrame
        let finalFrame = WireframePanelGeometry.frame(in: visibleFrame)

        if panel.isVisible {
            if wasDismissing {
                withAnimation(.easeOut(duration: 0.2)) {
                    presentation.phase = .board
                }
            }
            panel.makeKeyAndOrderFront(nil)
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presentation.phase = .hidden
            presentation.burstProgress = 0
        }
        panel.setFrame(finalFrame, display: false)
        panel.makeKeyAndOrderFront(nil)

        transitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(20))
                if !presentation.reducesMotion {
                    withAnimation(.easeOut(duration: 0.10)) { presentation.phase = .dot }
                    try await Task.sleep(for: .milliseconds(100))
                    withAnimation(.easeInOut(duration: 0.14)) { presentation.phase = .pill }
                    try await Task.sleep(for: .milliseconds(140))
                }
                withAnimation(.easeInOut(duration: 0.24)) { presentation.phase = .board }
            } catch {
                // A close/reopen superseded this transition.
            }
        }
    }

    func dismiss() {
        guard panel.isVisible, !isDismissing else { return }
        transitionTask?.cancel()
        isDismissing = true
        panel.ignoresMouseEvents = true
        model.finishPendingName()
        presentation.reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        transitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if presentation.reducesMotion {
                    withAnimation(.easeOut(duration: 0.18)) { presentation.phase = .hidden }
                    try await Task.sleep(for: .milliseconds(180))
                } else {
                    presentation.burstProgress = 0
                    withAnimation(.easeInOut(duration: 0.20)) { presentation.phase = .pill }
                    try await Task.sleep(for: .milliseconds(200))
                    withAnimation(.easeInOut(duration: 0.15)) { presentation.phase = .dot }
                    try await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeOut(duration: 0.06)) { presentation.phase = .burst }
                    try await Task.sleep(for: .milliseconds(20))
                    withAnimation(.easeOut(duration: 0.18)) { presentation.burstProgress = 1 }
                    try await Task.sleep(for: .milliseconds(180))
                }
                panel.orderOut(nil)
                presentation.phase = .hidden
                isDismissing = false
                onDismiss()
            } catch {
                // Cancellation must not order out a board that has reopened.
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        model.finishPendingName()
        if !model.isPinned {
            dismiss()
        }
    }

    private func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}

final class WireframePanel: NSPanel {
    var onEscape: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            if !event.isARepeat { onEscape?() }
            return
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
