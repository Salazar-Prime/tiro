import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let navigation = SettingsNavigationModel()

    init(model: AppModel, historyStore: TranscriptHistoryStore) {
        let rootView = SettingsView(
            model: model,
            historyStore: historyStore,
            navigation: navigation
        )
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Tiro"
        window.setContentSize(NSSize(width: 520, height: 700))
        window.minSize = NSSize(width: 480, height: 560)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.sharingType = .readOnly
        window.center()
        super.init(window: window)
    }

    func select(_ page: SettingsPage) {
        navigation.selectedPage = page
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
