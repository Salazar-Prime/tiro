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
    private var recordingScreenshotTasks: [Task<URL?, Never>] = []
    private var recordingIsLocked = false
    private var recordingEngine: TranscriptionEngine?
    private var latestInputLevel: Float = 0.2

    var onNeedsSettings: (() -> Void)?
    var onListeningChanged: ((Bool) -> Void)?

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
                showListening(level: 0.46)
            }
        case .finishRecording:
            finishRecording()
        case .cancelScheduledFinish, .scheduleFinish:
            break
        }
    }

    func captureScreenshot(using controller: ScreenshotCaptureController) {
        guard recorder.isRecording || pendingActivation != nil else { return }
        guard let task = controller.captureUsableScreenForTranscript() else { return }
        recordingScreenshotTasks.append(task)
        if recorder.isRecording {
            showListening(level: latestInputLevel)
        }
    }

    func appendImageToCurrentTranscript(_ fileURL: URL) -> Bool {
        guard recorder.isRecording || pendingActivation != nil else { return false }
        recordingScreenshotTasks.append(Task<URL?, Never> { fileURL })
        if recorder.isRecording {
            showListening(level: latestInputLevel)
        }
        return true
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
        onListeningChanged?(false)
        discardRecordingScreenshots()
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
        discardRecordingScreenshots()
        latestInputLevel = 0.2
        let activation = UUID()
        pendingActivation = activation
        overlay.show(.preparing)

        Task {
            let granted = await AudioRecorder.requestPermission()
            appModel.refreshPermissions()
            guard pendingActivation == activation else { return }
            guard granted else {
                pendingActivation = nil
                discardRecordingScreenshots()
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
                    self.showListening(level: level)
                }
                onListeningChanged?(true)
                showListening(level: 0.2)
            } catch {
                recordingEngine = nil
                discardRecordingScreenshots()
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
        onListeningChanged?(false)
        let screenshotTasks = recordingScreenshotTasks
        recordingScreenshotTasks.removeAll()
        outputMuter.restore()
        guard let fileURL else {
            screenshotTasks.forEach { $0.cancel() }
            overlay.hide()
            return
        }
        guard recordingDuration >= Self.minimumRecordingDuration else {
            screenshotTasks.forEach { $0.cancel() }
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
                var screenshotURLs: [URL] = []
                for screenshotTask in screenshotTasks {
                    if let fileURL = await screenshotTask.value {
                        screenshotURLs.append(fileURL)
                    }
                }
                let completedText = ScreenshotLinkFormatter.appending(
                    screenshotURLs,
                    to: text,
                    wrapper: appModel.screenshotPathWrapper
                )
                historyStore.add(completedText)
                switch await TextInsertionService.insert(completedText) {
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

    private func showListening(level: Float) {
        latestInputLevel = level
        overlay.show(
            .listening(
                level: level,
                locked: recordingIsLocked,
                screenshotCount: recordingScreenshotTasks.count
            )
        )
    }

    private func discardRecordingScreenshots() {
        recordingScreenshotTasks.forEach { $0.cancel() }
        recordingScreenshotTasks.removeAll()
    }
}

private enum VoiceTypingError: LocalizedError {
    case apiKeyMissing

    var errorDescription: String? {
        "Add an API key in Settings."
    }
}
