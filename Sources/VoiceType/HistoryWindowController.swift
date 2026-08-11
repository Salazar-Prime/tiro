import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    init(store: TranscriptHistoryStore) {
        let hosting = NSHostingController(rootView: HistoryView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Tiro History"
        window.setContentSize(NSSize(width: 620, height: 590))
        window.minSize = NSSize(width: 500, height: 440)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.sharingType = .readOnly
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
