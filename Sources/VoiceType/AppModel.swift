import AppKit
import AVFoundation
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let defaultTranscriptionInstructions = """
    Remove filler words. Correct grammar and spelling. Preserve the speaker's meaning. Format spoken lists as bullet points.
    """

    private static let transcriptionInstructionsKey = "transcriptionInstructions"
    private static let transcriptionEngineKey = "transcriptionEngine"
    private static let offlineInitialPromptKey = "offlineInitialPrompt"
    private static let screenCapturePermissionRequestedKey = "screenCapturePermissionRequested"
    private static let shortcutConfigurationKey = "shortcutConfiguration"
    private static let screenshotPathWrappingEnabledKey = "screenshotPathWrappingEnabled"
    private static let screenshotPathPrefixKey = "screenshotPathPrefix"
    private static let screenshotPathSuffixKey = "screenshotPathSuffix"

    @Published private(set) var hasAPIKey = false
    @Published private(set) var microphoneStatus: PermissionStatus = .unknown
    @Published private(set) var accessibilityStatus: PermissionStatus = .unknown
    @Published private(set) var screenCaptureStatus: PermissionStatus = .unknown
    @Published private(set) var screenshotCaptureIsBusy = false
    @Published private(set) var shortcutConfiguration: ShortcutConfiguration
    @Published private(set) var shortcutMessage: String?
    @Published var keyEntry = ""
    @Published var keyMessage: String?
    @Published var screenshotPathWrappingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                screenshotPathWrappingEnabled,
                forKey: Self.screenshotPathWrappingEnabledKey
            )
        }
    }
    @Published var screenshotPathPrefix: String {
        didSet {
            UserDefaults.standard.set(
                screenshotPathPrefix,
                forKey: Self.screenshotPathPrefixKey
            )
        }
    }
    @Published var screenshotPathSuffix: String {
        didSet {
            UserDefaults.standard.set(
                screenshotPathSuffix,
                forKey: Self.screenshotPathSuffixKey
            )
        }
    }
    @Published var transcriptionEngine: TranscriptionEngine {
        didSet {
            UserDefaults.standard.set(
                transcriptionEngine.rawValue,
                forKey: Self.transcriptionEngineKey
            )
        }
    }
    @Published var transcriptionInstructions: String {
        didSet {
            UserDefaults.standard.set(
                transcriptionInstructions,
                forKey: Self.transcriptionInstructionsKey
            )
        }
    }
    @Published var offlineInitialPrompt: String {
        didSet {
            UserDefaults.standard.set(
                offlineInitialPrompt,
                forKey: Self.offlineInitialPromptKey
            )
        }
    }

    var onPreviewOverlay: (() -> Void)?
    var onCaptureUsableScreen: (() -> Void)?
    var onCaptureSelection: (() -> Void)?
    var onOpenScreenshotsFolder: (() -> Void)?
    var onShortcutsChanged: ((ShortcutConfiguration) -> Void)?
    var onShortcutRecordingChanged: ((Bool) -> Void)?
    let offlineModel: OfflineModelManager

    var isAccessibilityTrusted: Bool {
        accessibilityStatus == .granted
    }

    var isSelectedEngineReady: Bool {
        switch transcriptionEngine {
        case .cloud:
            hasAPIKey && currentAPIKey() != nil
        case .offline:
            offlineModel.isReady
        }
    }

    var screenshotPathWrapper: ScreenshotPathWrapper {
        ScreenshotPathWrapper(
            isEnabled: screenshotPathWrappingEnabled,
            prefix: screenshotPathPrefix,
            suffix: screenshotPathSuffix
        )
    }

    init(offlineModel: OfflineModelManager? = nil) {
        self.offlineModel = offlineModel ?? OfflineModelManager()
        shortcutConfiguration = Self.loadShortcutConfiguration()
        screenshotPathWrappingEnabled = UserDefaults.standard.object(
            forKey: Self.screenshotPathWrappingEnabledKey
        ) as? Bool ?? true
        screenshotPathPrefix = UserDefaults.standard.object(
            forKey: Self.screenshotPathPrefixKey
        ) as? String ?? "'"
        screenshotPathSuffix = UserDefaults.standard.object(
            forKey: Self.screenshotPathSuffixKey
        ) as? String ?? "'"
        transcriptionEngine = UserDefaults.standard.string(
            forKey: Self.transcriptionEngineKey
        ).flatMap(TranscriptionEngine.init(rawValue:)) ?? .cloud
        transcriptionInstructions = UserDefaults.standard.object(
            forKey: Self.transcriptionInstructionsKey
        ) as? String ?? Self.defaultTranscriptionInstructions
        offlineInitialPrompt = UserDefaults.standard.string(
            forKey: Self.offlineInitialPromptKey
        ) ?? ""
        hasAPIKey = (try? KeychainStore.loadAPIKey())?.isEmpty == false
        refreshPermissions()
    }

    func refreshPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notRequested
        @unknown default:
            microphoneStatus = .unknown
        }

        accessibilityStatus = AXIsProcessTrusted() ? .granted : .notRequested

        if CGPreflightScreenCaptureAccess() {
            screenCaptureStatus = .granted
        } else if UserDefaults.standard.bool(
            forKey: Self.screenCapturePermissionRequestedKey
        ) {
            screenCaptureStatus = .denied
        } else {
            screenCaptureStatus = .notRequested
        }
    }

    func saveAPIKey() {
        let value = keyEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            keyMessage = "Enter an API key first."
            return
        }

        do {
            try KeychainStore.saveAPIKey(value)
            keyEntry = ""
            hasAPIKey = true
            keyMessage = "Saved securely in Keychain."
        } catch {
            keyMessage = "Keychain could not save the key."
        }
    }

    func removeAPIKey() {
        do {
            try KeychainStore.deleteAPIKey()
            hasAPIKey = false
            keyEntry = ""
            keyMessage = "API key removed."
        } catch {
            keyMessage = "Keychain could not remove the key."
        }
    }

    func requestMicrophone() {
        Task {
            _ = await AudioRecorder.requestPermission()
            refreshPermissions()
            if microphoneStatus == .denied {
                openPrivacySettings(anchor: "Privacy_Microphone")
            }
        }
    }

    func requestAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt"
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        refreshPermissions()
        if !isAccessibilityTrusted {
            openPrivacySettings(anchor: "Privacy_Accessibility")
        }
    }

    func requestScreenCapture() {
        UserDefaults.standard.set(
            true,
            forKey: Self.screenCapturePermissionRequestedKey
        )
        let granted = CGRequestScreenCaptureAccess()
        screenCaptureStatus = granted ? .granted : .denied
        if !granted {
            openPrivacySettings(anchor: "Privacy_ScreenCapture")
        }
    }

    func previewOverlay() {
        onPreviewOverlay?()
    }

    func captureUsableScreen() {
        onCaptureUsableScreen?()
    }

    func captureSelection() {
        onCaptureSelection?()
    }

    func openScreenshotsFolder() {
        onOpenScreenshotsFolder?()
    }

    func setScreenshotCaptureBusy(_ isBusy: Bool) {
        screenshotCaptureIsBusy = isBusy
    }

    func resetScreenshotPathWrapper() {
        screenshotPathWrappingEnabled = true
        screenshotPathPrefix = "'"
        screenshotPathSuffix = "'"
    }

    func setShortcut(_ shortcut: TiroShortcut?, for action: ShortcutAction) {
        var updated = shortcutConfiguration
        do {
            try updated.set(shortcut, for: action)
            shortcutConfiguration = updated
            shortcutMessage = "Shortcuts updated."
            saveShortcutConfiguration()
            onShortcutsChanged?(updated)
        } catch {
            shortcutMessage = error.localizedDescription
        }
    }

    func resetShortcuts() {
        shortcutConfiguration = .defaults
        shortcutMessage = "Default shortcuts restored."
        saveShortcutConfiguration()
        onShortcutsChanged?(shortcutConfiguration)
    }

    func setShortcutRecordingActive(_ isActive: Bool) {
        onShortcutRecordingChanged?(isActive)
    }

    func reportShortcutRegistrationFailure(_ action: ShortcutAction) {
        shortcutMessage = "macOS or another app is already using the shortcut for \(action.title.lowercased())."
    }

    func currentAPIKey() -> String? {
        try? KeychainStore.loadAPIKey()
    }

    func resetTranscriptionInstructions() {
        transcriptionInstructions = Self.defaultTranscriptionInstructions
    }

    func prompt(for engine: TranscriptionEngine) -> String {
        switch engine {
        case .cloud: transcriptionInstructions
        case .offline: offlineInitialPrompt
        }
    }

    func resetPromptForSelectedEngine() {
        switch transcriptionEngine {
        case .cloud: resetTranscriptionInstructions()
        case .offline: offlineInitialPrompt = ""
        }
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func loadShortcutConfiguration() -> ShortcutConfiguration {
        guard let data = UserDefaults.standard.data(forKey: shortcutConfigurationKey),
              var decoded = try? JSONDecoder().decode(
                  ShortcutConfiguration.self,
                  from: data
              )
        else { return .defaults }

        decoded.normalizeContextShortcuts()
        guard (try? decoded.validate()) != nil else { return .defaults }
        return decoded
    }

    private func saveShortcutConfiguration() {
        guard let data = try? JSONEncoder().encode(shortcutConfiguration) else { return }
        UserDefaults.standard.set(data, forKey: Self.shortcutConfigurationKey)
    }
}

enum PermissionStatus: Equatable {
    case unknown
    case notRequested
    case granted
    case denied

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .notRequested: "Not granted"
        case .granted: "Ready"
        case .denied: "Blocked"
        }
    }
}
