import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var outputURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return false
        }
    }

    func start(onLevel: @escaping @MainActor @Sendable (Float) -> Void) throws {
        guard !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceType-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.couldNotStart
        }

        self.recorder = recorder
        outputURL = url
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.065, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let decibels = recorder.averagePower(forChannel: 0)
                let normalized = max(0, min(1, (decibels + 52) / 52))
                onLevel(normalized)
            }
        }
    }

    func stop() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        defer { outputURL = nil }
        return outputURL
    }

    func cancel() {
        let url = stop()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "The microphone could not start recording."
    }
}
