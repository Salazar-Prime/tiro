import AppKit
@preconcurrency import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private let appModel = AppModel()
    private let historyStore = TranscriptHistoryStore()
    private let overlayController = OverlayWindowController()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )
    private var voiceController: VoiceTypingController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var settingsWindowController: SettingsWindowController?
    private var historyWindowController: HistoryWindowController?
    private var statusItem: NSStatusItem?
    private var updateMenuItem: NSMenuItem?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        let hotkeyMonitor = HotkeyMonitor(
            onVoiceAction: { [weak voiceController] action in
                voiceController?.handle(action)
            },
            onPaste: { [weak voiceController] in
                voiceController?.pasteLastTranscript()
            }
        )
        hotkeyMonitor.start()
        self.hotkeyMonitor = hotkeyMonitor

        appModel.onPreviewOverlay = { [weak self] in
            self?.overlayController.show(.listening(level: 0.58, locked: true))
            self?.overlayController.hide(after: 1.6)
        }

        configureStatusItem()
        appModel.refreshPermissions()

        if !appModel.hasAPIKey {
            openSettings()
        } else if !appModel.isAccessibilityTrusted {
            appModel.requestAccessibility()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appModel.refreshPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
        voiceController?.cancelRecording()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func openHistoryFromMenu() {
        openHistory()
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: appModel)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func openHistory() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController(store: historyStore)
        }
        historyWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        historyWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "waveform.and.mic",
            accessibilityDescription: "Voice Type"
        )

        let menu = NSMenu()
        let heading = NSMenuItem(title: "Voice Type", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())

        let historyItem = NSMenuItem(
            title: "Transcript History…",
            action: #selector(openHistoryFromMenu),
            keyEquivalent: ""
        )
        historyItem.target = self
        menu.addItem(historyItem)

        let pasteHint = NSMenuItem(
            title: "⌃⌘V  Paste last transcript",
            action: nil,
            keyEquivalent: ""
        )
        pasteHint.isEnabled = false
        menu.addItem(pasteHint)

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
            title: "Quit Voice Type",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        updateMenuItem?.title = "Update \(update.displayVersionString) Available…"
        statusItem?.button?.image = NSImage(
            systemSymbolName: "arrow.down.circle.fill",
            accessibilityDescription: "Voice Type update available"
        )
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        resetUpdateIndicator()
    }

    func standardUserDriverWillFinishUpdateSession() {
        resetUpdateIndicator()
    }

    private func resetUpdateIndicator() {
        updateMenuItem?.title = "Check for Updates…"
        statusItem?.button?.image = NSImage(
            systemSymbolName: "waveform.and.mic",
            accessibilityDescription: "Voice Type"
        )
    }
}
