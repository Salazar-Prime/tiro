import Foundation

@MainActor
final class VoiceTypingController {
    private static let minimumRecordingDuration: TimeInterval = 0.5

    private let appModel: AppModel
    private let overlay: OverlayWindowController
    private let recorder = AudioRecorder()
    private let client = TranscriptionClient()
    private let offlineClient = OfflineTranscriptionClient()
    private let historyStore: TranscriptHistoryStore
    private let outputMuter = SystemOutputMuter()

    private var pendingActivation: UUID?
    private var transcriptionTask: Task<Void, Never>?
    private var recordingIsLocked = false
    private var recordingEngine: TranscriptionEngine?

    var onNeedsSettings: (() -> Void)?

    init(
        appModel: AppModel,
        overlay: OverlayWindowController,
        historyStore: TranscriptHistoryStore
    ) {
        self.appModel = appModel
        self.overlay = overlay
        self.historyStore = historyStore
    }

    func handle(_ action: VoiceGestureAction) {
        switch action {
        case .beginRecording:
            beginRecording()
        case .lockRecording:
            recordingIsLocked = true
            if recorder.isRecording {
                overlay.show(.listening(level: 0.46, locked: true))
            }
        case .finishRecording:
            finishRecording()
        case .cancelScheduledFinish, .scheduleFinish:
            break
        }
    }

    func pasteLastTranscript() {
        Task { [weak self] in
            await self?.pasteLastTranscriptNow()
        }
    }

    private func pasteLastTranscriptNow() async {
        guard let text = historyStore.latest?.text else {
            overlay.show(.error("Nothing saved yet"))
            overlay.hide(after: 1.4)
            return
        }

        switch await TextInsertionService.insert(text) {
        case .insertedDirectly:
            overlay.show(.success("Pasted again"))
        case .pasteCommandSent:
            overlay.show(.success("Paste sent"))
        case .accessibilityUnavailable:
            overlay.show(.error("Enable Accessibility"))
            onNeedsSettings?()
        case .noActiveTarget:
            overlay.show(.error("Focus a text field"))
        case .failed:
            overlay.show(.error("Paste failed"))
        }
        overlay.hide(after: 1.4)
    }

    func cancelRecording() {
        pendingActivation = nil
        recordingIsLocked = false
        recordingEngine = nil
        recorder.cancel()
        outputMuter.restore()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        overlay.hide()
    }

    private func beginRecording() {
        guard !recorder.isRecording, transcriptionTask == nil else {
            overlay.show(.error("Still transcribing"))
            overlay.hide(after: 1.2)
            return
        }
        let engine = appModel.transcriptionEngine
        switch engine {
        case .cloud:
            guard appModel.hasAPIKey, appModel.currentAPIKey() != nil else {
                overlay.show(.error("Add an API key"))
                overlay.hide(after: 1.5)
                onNeedsSettings?()
                return
            }
        case .offline:
            guard appModel.offlineModel.isReady else {
                overlay.show(.error("Download offline model"))
                overlay.hide(after: 1.7)
                onNeedsSettings?()
                return
            }
        }

        recordingIsLocked = false
        recordingEngine = engine
        let activation = UUID()
        pendingActivation = activation
        overlay.show(.preparing)

        Task {
            let granted = await AudioRecorder.requestPermission()
            appModel.refreshPermissions()
            guard pendingActivation == activation else { return }
            guard granted else {
                pendingActivation = nil
                overlay.show(.error("Microphone blocked"))
                overlay.hide(after: 1.6)
                onNeedsSettings?()
                return
            }

            do {
                await outputMuter.mute()
                guard pendingActivation == activation else {
                    outputMuter.restore()
                    return
                }
                pendingActivation = nil
                try recorder.start(
                    format: engine == .offline ? .whisperPCM : .compressed
                ) { [weak self] level in
                    guard let self else { return }
                    self.overlay.show(.listening(level: level, locked: self.recordingIsLocked))
                }
                overlay.show(.listening(level: 0.2, locked: recordingIsLocked))
            } catch {
                recordingEngine = nil
                outputMuter.restore()
                overlay.show(.error("Microphone unavailable"))
                overlay.hide(after: 1.6)
            }
        }
    }

    private func finishRecording() {
        pendingActivation = nil
        recordingIsLocked = false
        let engine = recordingEngine ?? appModel.transcriptionEngine
        recordingEngine = nil
        let recordingDuration = recorder.recordingDuration
        let fileURL = recorder.stop()
        outputMuter.restore()
        guard let fileURL else {
            overlay.hide()
            return
        }
        guard recordingDuration >= Self.minimumRecordingDuration else {
            try? FileManager.default.removeItem(at: fileURL)
            overlay.show(.error("Recording too short"))
            overlay.hide(after: 1.4)
            return
        }
        overlay.show(.transcribing)
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: fileURL)
                transcriptionTask = nil
            }

            do {
                let text: String
                switch engine {
                case .cloud:
                    guard let apiKey = appModel.currentAPIKey() else {
                        throw VoiceTypingError.apiKeyMissing
                    }
                    text = try await client.transcribe(
                        fileURL: fileURL,
                        apiKey: apiKey,
                        prompt: appModel.prompt(for: engine)
                    )
                case .offline:
                    text = try await offlineClient.transcribe(
                        fileURL: fileURL,
                        modelURL: appModel.offlineModel.modelURL,
                        prompt: appModel.prompt(for: engine)
                    )
                }
                guard !Task.isCancelled else { return }
                historyStore.add(text)
                switch await TextInsertionService.insert(text) {
                case .insertedDirectly:
                    overlay.show(.success("Pasted"))
                case .pasteCommandSent:
                    overlay.show(.success("Paste sent"))
                case .accessibilityUnavailable:
                    overlay.show(.error("Saved — enable Accessibility"))
                    onNeedsSettings?()
                case .noActiveTarget:
                    overlay.show(.success("Saved — focus a text field"))
                case .failed:
                    overlay.show(.success("Saved in history"))
                }
                overlay.hide(after: 1.5)
            } catch is CancellationError {
                overlay.hide()
            } catch {
                overlay.show(.error(error.localizedDescription))
                overlay.hide(after: 2.4)
            }
        }
    }
}

private enum VoiceTypingError: LocalizedError {
    case apiKeyMissing

    var errorDescription: String? {
        "Add an API key in Settings."
    }
}
