import Foundation
import whisper

actor OfflineTranscriptionClient {
    private var contextHandle: WhisperContextHandle?
    private var loadedModelPath: String?

    func transcribe(fileURL: URL, modelURL: URL, prompt: String) throws -> String {
        let samples = try WhisperWaveDecoder.decode(fileURL)
        let context = try loadContext(at: modelURL)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        var parameters = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        parameters.print_realtime = false
        parameters.print_progress = false
        parameters.print_timestamps = false
        parameters.print_special = false
        parameters.translate = false
        parameters.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        parameters.offset_ms = 0
        parameters.no_context = true
        parameters.single_segment = false

        let result: Int32 = "en".withCString { language in
            parameters.language = language
            return samples.withUnsafeBufferPointer { sampleBuffer in
                guard let sampleAddress = sampleBuffer.baseAddress else { return -1 }
                if trimmedPrompt.isEmpty {
                    parameters.initial_prompt = nil
                    return whisper_full(
                        context,
                        parameters,
                        sampleAddress,
                        Int32(sampleBuffer.count)
                    )
                }
                return trimmedPrompt.withCString { initialPrompt in
                    parameters.initial_prompt = initialPrompt
                    return whisper_full(
                        context,
                        parameters,
                        sampleAddress,
                        Int32(sampleBuffer.count)
                    )
                }
            }
        }
        guard result == 0 else {
            throw OfflineTranscriptionError.transcriptionFailed
        }

        var transcript = ""
        for index in 0..<whisper_full_n_segments(context) {
            guard let segment = whisper_full_get_segment_text(context, index) else { continue }
            transcript += String(cString: segment)
        }
        return try TranscriptionClient.validatedTranscript(transcript, prompt: trimmedPrompt)
    }

    private func loadContext(at modelURL: URL) throws -> OpaquePointer {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw OfflineTranscriptionError.modelMissing
        }
        if loadedModelPath == modelURL.path, let contextHandle {
            return contextHandle.pointer
        }
        contextHandle = nil

        var parameters = whisper_context_default_params()
        parameters.use_gpu = true
        parameters.flash_attn = true
        guard let context = whisper_init_from_file_with_params(modelURL.path, parameters) else {
            throw OfflineTranscriptionError.modelCouldNotLoad
        }
        contextHandle = WhisperContextHandle(pointer: context)
        loadedModelPath = modelURL.path
        return context
    }
}

private final class WhisperContextHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        whisper_free(pointer)
    }
}

enum OfflineTranscriptionError: LocalizedError, Equatable {
    case invalidAudio
    case unsupportedAudio
    case modelMissing
    case modelCouldNotLoad
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidAudio:
            "The recording could not be read."
        case .unsupportedAudio:
            "The recording format is not supported offline."
        case .modelMissing:
            "Download the offline model in Settings."
        case .modelCouldNotLoad:
            "The offline model could not be loaded."
        case .transcriptionFailed:
            "Offline transcription failed."
        }
    }
}

enum WhisperWaveDecoder {
    static func decode(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 44,
              String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE"
        else {
            throw OfflineTranscriptionError.invalidAudio
        }

        var format: (code: UInt16, channels: UInt16, sampleRate: UInt32, bits: UInt16)?
        var audioRange: Range<Int>?
        var offset = 12
        while offset + 8 <= data.count {
            let identifier = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let chunkSize = Int(readUInt32(data, at: offset + 4))
            let contentStart = offset + 8
            let contentEnd = contentStart + chunkSize
            guard contentEnd <= data.count else {
                throw OfflineTranscriptionError.invalidAudio
            }

            if identifier == "fmt ", chunkSize >= 16 {
                format = (
                    readUInt16(data, at: contentStart),
                    readUInt16(data, at: contentStart + 2),
                    readUInt32(data, at: contentStart + 4),
                    readUInt16(data, at: contentStart + 14)
                )
            } else if identifier == "data" {
                audioRange = contentStart..<contentEnd
            }
            offset = contentEnd + (chunkSize.isMultiple(of: 2) ? 0 : 1)
        }

        guard let format, format.code == 1, format.channels == 1,
              format.sampleRate == 16_000, format.bits == 16,
              let audioRange, !audioRange.isEmpty
        else {
            throw OfflineTranscriptionError.unsupportedAudio
        }

        var samples: [Float] = []
        samples.reserveCapacity(audioRange.count / 2)
        var sampleOffset = audioRange.lowerBound
        while sampleOffset + 1 < audioRange.upperBound {
            let sample = Int16(bitPattern: readUInt16(data, at: sampleOffset))
            samples.append(max(-1, min(1, Float(sample) / 32_768)))
            sampleOffset += 2
        }
        guard !samples.isEmpty else {
            throw OfflineTranscriptionError.invalidAudio
        }
        return samples
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
