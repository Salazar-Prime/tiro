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

    var recordingDuration: TimeInterval {
        recorder?.currentTime ?? 0
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

    func start(
        format: AudioRecordingFormat = .compressed,
        onLevel: @escaping @MainActor @Sendable (Float) -> Void
    ) throws {
        guard !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tiro-\(UUID().uuidString)")
            .appendingPathExtension(format.fileExtension)
        let settings = format.settings

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

enum AudioRecordingFormat {
    case compressed
    case whisperPCM

    var fileExtension: String {
        switch self {
        case .compressed: "m4a"
        case .whisperPCM: "wav"
        }
    }

    var settings: [String: Any] {
        switch self {
        case .compressed:
            [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        case .whisperPCM:
            [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "The microphone could not start recording."
    }
}
