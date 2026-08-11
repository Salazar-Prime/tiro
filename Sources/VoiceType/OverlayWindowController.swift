import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let model = OverlayModel()
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?
    private let panelSize = NSSize(width: 190, height: 58)

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.sharingType = .readOnly
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.contentView = NSHostingView(rootView: OverlayPillView(model: model))
    }

    func show(_ state: OverlayState) {
        hideTask?.cancel()
        hideTask = nil
        model.state = state

        guard !panel.isVisible else { return }
        let finalFrame = frameOnActiveScreen()
        var initialFrame = finalFrame
        initialFrame.origin.x += 14
        panel.setFrame(initialFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide(after delay: TimeInterval = 0) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self else { return }
            hideNow()
        }
    }

    private func hideNow() {
        guard panel.isVisible else { return }
        var hiddenFrame = panel.frame
        hiddenFrame.origin.x += 10
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.13
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            MainActor.assumeIsolated {
                panel?.orderOut(nil)
            }
        })
    }

    private func frameOnActiveScreen() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.maxX - panelSize.width - 18,
            y: visible.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

@MainActor
final class OverlayModel: ObservableObject {
    @Published var state: OverlayState = .preparing
}

enum OverlayState: Equatable {
    case preparing
    case listening(level: Float, locked: Bool)
    case transcribing
    case success(String)
    case error(String)
}
