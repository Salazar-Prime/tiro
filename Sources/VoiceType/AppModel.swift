import AppKit
import AVFoundation
import ApplicationServices
import Foundation

@MainActor
final class AppModel: ObservableObject {
    static let defaultTranscriptionInstructions = """
    Remove filler words. Correct grammar and spelling. Preserve the speaker's meaning. Format spoken lists as bullet points.
    """

    private static let transcriptionInstructionsKey = "transcriptionInstructions"
    private static let transcriptionEngineKey = "transcriptionEngine"
    private static let offlineInitialPromptKey = "offlineInitialPrompt"

    @Published private(set) var hasAPIKey = false
    @Published private(set) var microphoneStatus: PermissionStatus = .unknown
    @Published private(set) var accessibilityStatus: PermissionStatus = .unknown
    @Published var keyEntry = ""
    @Published var keyMessage: String?
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

    init(offlineModel: OfflineModelManager? = nil) {
        self.offlineModel = offlineModel ?? OfflineModelManager()
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

    func previewOverlay() {
        onPreviewOverlay?()
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
