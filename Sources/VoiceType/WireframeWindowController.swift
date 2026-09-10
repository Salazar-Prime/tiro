import AppKit
import SwiftUI

@MainActor
final class WireframeWindowController: NSObject, NSWindowDelegate {
    private let model: WireframeCanvasModel
    private let exporter: WireframeExporter
    private let panel: WireframePanel
    private let onDismiss: () -> Void
    private var isDismissing = false

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

        panel.delegate = self
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
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
            rootView: WireframeBoardView(
                model: model,
                onExport: { action, colorScheme in
                    exporter.perform(
                        action,
                        elements: model.elements,
                        revision: model.contentRevision,
                        colorScheme: colorScheme
                    )
                },
                onClose: { [weak self] in self?.dismiss() }
            )
        )
    }

    func show() {
        isDismissing = false
        let visibleFrame = activeScreen().visibleFrame
        let finalFrame = WireframePanelGeometry.frame(in: visibleFrame)

        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        var initialFrame = finalFrame
        initialFrame.origin.x = visibleFrame.maxX + 8
        panel.setFrame(initialFrame, display: false)
        panel.alphaValue = 0.4
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard panel.isVisible, !isDismissing else { return }
        isDismissing = true
        model.finishPendingName()
        let visibleFrame = panel.screen?.visibleFrame ?? activeScreen().visibleFrame
        var hiddenFrame = panel.frame
        hiddenFrame.origin.x = visibleFrame.maxX + 8

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.19
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame, display: true)
            panel.animator().alphaValue = 0.35
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.isDismissing = false
                self.onDismiss()
            }
        })
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

private final class WireframePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
