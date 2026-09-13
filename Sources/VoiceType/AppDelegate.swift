import AppKit
@preconcurrency import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let appModel = AppModel()
    private let historyStore = TranscriptHistoryStore()
    private let overlayController = OverlayWindowController()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    private var voiceController: VoiceTypingController?
    private var screenshotController: ScreenshotCaptureController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var settingsWindowController: SettingsWindowController?
    private var wireframeWindowController: WireframeWindowController?
    private var statusItem: NSStatusItem?
    private var updateMenuItem: NSMenuItem?
    private var pasteHintMenuItem: NSMenuItem?
    private var wireframeMenuItem: NSMenuItem?
    private var historyMenuItem: NSMenuItem?
    private var captureScreenMenuItem: NSMenuItem?
    private var captureSelectionMenuItem: NSMenuItem?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationIcon()
        NSApp.setActivationPolicy(.accessory)

        let voiceController = VoiceTypingController(
            appModel: appModel,
            overlay: overlayController,
            historyStore: historyStore
        )
        voiceController.onNeedsSettings = { [weak self] in
            self?.openSettings()
        }
        self.voiceController = voiceController

        let screenshotController = ScreenshotCaptureController(
            model: appModel,
            overlay: overlayController,
            historyStore: historyStore
        )
        self.screenshotController = screenshotController

        let hotkeyMonitor = HotkeyMonitor(
            shortcuts: appModel.shortcutConfiguration,
            onVoiceAction: { [weak voiceController] action in
                voiceController?.handle(action)
            },
            onPaste: { [weak voiceController] in
                voiceController?.pasteLastTranscript()
            },
            onOpenWireframe: { [weak self] in
                self?.openWireframe()
            },
            onOpenHistory: { [weak self] in
                self?.openHistory()
            },
            onScreenshot: { [weak voiceController, weak screenshotController] in
                guard let screenshotController else { return }
                voiceController?.captureScreenshot(using: screenshotController)
            },
            onCaptureScreen: { [weak screenshotController] in
                screenshotController?.capture(.usableScreen)
            },
            onCaptureSelection: { [weak screenshotController] in
                screenshotController?.capture(.selection)
            },
            onRegistrationFailure: { [weak appModel] action in
                appModel?.reportShortcutRegistrationFailure(action)
            }
        )
        hotkeyMonitor.start()
        self.hotkeyMonitor = hotkeyMonitor
        voiceController.onListeningChanged = { [weak hotkeyMonitor] isListening in
            hotkeyMonitor?.setVoiceTypingActive(isListening)
        }

        appModel.onPreviewOverlay = { [weak self] in
            self?.overlayController.show(
                .listening(level: 0.58, locked: true, screenshotCount: 0)
            )
            self?.overlayController.hide(after: 1.6)
        }
        appModel.onCaptureUsableScreen = { [weak screenshotController] in
            screenshotController?.capture(.usableScreen)
        }
        appModel.onCaptureSelection = { [weak screenshotController] in
            screenshotController?.capture(.selection)
        }
        appModel.onOpenScreenshotsFolder = { [weak screenshotController] in
            screenshotController?.openScreenshotsFolder()
        }
        appModel.onShortcutsChanged = { [weak self, weak hotkeyMonitor] shortcuts in
            hotkeyMonitor?.updateShortcuts(shortcuts)
            self?.updateShortcutMenuItems(shortcuts)
        }
        appModel.onShortcutRecordingChanged = { [weak hotkeyMonitor] isActive in
            hotkeyMonitor?.setPausedForShortcutRecording(isActive)
        }

        configureStatusItem()
        appModel.refreshPermissions()

        if !appModel.isSelectedEngineReady {
            openSettings()
        } else if !appModel.isAccessibilityTrusted {
            appModel.requestAccessibility()
        }
    }

    private func configureApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApp.applicationIconImage = icon
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appModel.refreshPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
        voiceController?.cancelRecording()
        screenshotController?.cancel()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func openHistoryFromMenu() {
        openHistory()
    }

    @objc private func openWireframeFromMenu() {
        openWireframe()
    }

    @objc private func captureUsableScreenFromMenu() {
        appModel.captureUsableScreen()
    }

    @objc private func captureSelectionFromMenu() {
        appModel.captureSelection()
    }

    @objc private func openScreenshotsFolderFromMenu() {
        appModel.openScreenshotsFolder()
    }

    private func openSettings(page: SettingsPage? = nil) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                model: appModel,
                historyStore: historyStore
            )
            settingsWindowController?.window?.delegate = self
        }
        if let page {
            settingsWindowController?.select(page)
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func openHistory() {
        openSettings(page: .history)
    }

    private func openWireframe() {
        if wireframeWindowController == nil {
            wireframeWindowController = WireframeWindowController(
                pathWrapper: { [weak self] in
                    self?.appModel.screenshotPathWrapper ?? .defaultValue
                },
                onDismiss: { [weak self] in
                    self?.wireframeDidDismiss()
                }
            )
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        wireframeWindowController?.show()
    }

    private func wireframeDidDismiss() {
        let settingsIsOpen = settingsWindowController?.window.map {
            $0.isVisible || $0.isMiniaturized
        } ?? false
        if !settingsIsOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        let utilityWindows = [settingsWindowController?.window].compactMap { $0 }

        guard utilityWindows.contains(where: { $0 === closingWindow }) else { return }

        let hasAnotherOpenWindow = utilityWindows.contains {
            $0 !== closingWindow && ($0.isVisible || $0.isMiniaturized)
        }
        if !hasAnotherOpenWindow, wireframeWindowController?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        keepDockIconVisible(for: notification)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        keepDockIconVisible(for: notification)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        keepDockIconVisible(for: notification)
    }

    private func keepDockIconVisible(for notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let isUtilityWindow = settingsWindowController?.window === window
        guard isUtilityWindow else { return }
        NSApp.setActivationPolicy(.regular)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = TiroMenuBarIcon.make()
        item.button?.imageScaling = .scaleProportionallyDown

        let menu = NSMenu()
        let heading = NSMenuItem(title: "Tiro", action: nil, keyEquivalent: "")
        if let brandImage = NSApp.applicationIconImage.copy() as? NSImage {
            brandImage.size = NSSize(width: 18, height: 18)
            heading.image = brandImage
        }
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        let wireframeItem = NSMenuItem(
            title: "Wireframe Board…",
            action: #selector(openWireframeFromMenu),
            keyEquivalent: ""
        )
        wireframeItem.image = NSImage(
            systemSymbolName: "square.grid.3x3",
            accessibilityDescription: "Open Wireframe Board"
        )
        wireframeItem.target = self
        menu.addItem(wireframeItem)
        wireframeMenuItem = wireframeItem
        menu.addItem(.separator())

        let historyItem = NSMenuItem(
            title: "Transcript History…",
            action: #selector(openHistoryFromMenu),
            keyEquivalent: ""
        )
        historyItem.target = self
        menu.addItem(historyItem)
        historyMenuItem = historyItem

        let pasteHint = NSMenuItem(
            title: "Paste last capture",
            action: nil,
            keyEquivalent: ""
        )
        pasteHint.isEnabled = false
        menu.addItem(pasteHint)
        pasteHintMenuItem = pasteHint
        menu.addItem(.separator())

        let usableScreenItem = NSMenuItem(
            title: "Capture Screen (without Menu Bar & Dock)",
            action: #selector(captureUsableScreenFromMenu),
            keyEquivalent: ""
        )
        usableScreenItem.image = NSImage(
            systemSymbolName: "rectangle.inset.filled",
            accessibilityDescription: "Capture screen"
        )
        usableScreenItem.target = self
        menu.addItem(usableScreenItem)
        captureScreenMenuItem = usableScreenItem

        let selectionItem = NSMenuItem(
            title: "Capture Selection…",
            action: #selector(captureSelectionFromMenu),
            keyEquivalent: ""
        )
        selectionItem.image = NSImage(
            systemSymbolName: "viewfinder",
            accessibilityDescription: "Capture selection"
        )
        selectionItem.target = self
        menu.addItem(selectionItem)
        captureSelectionMenuItem = selectionItem

        let screenshotsFolderItem = NSMenuItem(
            title: "Open Tiro Screenshots",
            action: #selector(openScreenshotsFolderFromMenu),
            keyEquivalent: ""
        )
        screenshotsFolderItem.target = self
        menu.addItem(screenshotsFolderItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        menu.addItem(updateItem)
        updateMenuItem = updateItem
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Tiro",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
        updateShortcutMenuItems(appModel.shortcutConfiguration)
    }

    private func updateShortcutMenuItems(_ shortcuts: ShortcutConfiguration) {
        let pasteLabel = shortcuts.pasteLast?.displayName ?? "Not set"
        pasteHintMenuItem?.title = "\(pasteLabel)  Paste last capture"
        applyMenuShortcut(shortcuts.openWireframe, to: wireframeMenuItem)
        applyMenuShortcut(shortcuts.openHistory, to: historyMenuItem)
        applyMenuShortcut(shortcuts.captureScreen, to: captureScreenMenuItem)
        applyMenuShortcut(shortcuts.captureSelection, to: captureSelectionMenuItem)
    }

    private func applyMenuShortcut(_ shortcut: TiroShortcut?, to item: NSMenuItem?) {
        guard let item,
              let shortcut,
              let keyEquivalent = shortcut.menuKeyEquivalent
        else {
            item?.keyEquivalent = ""
            item?.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = shortcut.eventModifierFlags
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        updateMenuItem?.title = "Update \(update.displayVersionString) Available…"
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        resetUpdateIndicator()
    }

    func standardUserDriverWillFinishUpdateSession() {
        resetUpdateIndicator()
    }

    private func resetUpdateIndicator() {
        updateMenuItem?.title = "Check for Updates…"
        statusItem?.button?.image = TiroMenuBarIcon.make()
    }
}
