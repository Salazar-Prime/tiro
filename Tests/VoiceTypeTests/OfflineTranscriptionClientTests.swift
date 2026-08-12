import Foundation
import XCTest
@testable import VoiceType

final class OfflineTranscriptionClientTests: XCTestCase {
    func testDecodesMono16KHzPCMIntoNormalizedSamples() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiroWaveTest-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try waveData(samples: [0, Int16.max, Int16.min]).write(to: url)

        let samples = try WhisperWaveDecoder.decode(url)

        XCTAssertEqual(samples.count, 3)
        XCTAssertEqual(samples[0], 0, accuracy: 0.0001)
        XCTAssertEqual(samples[1], Float(Int16.max) / 32_768, accuracy: 0.0001)
        XCTAssertEqual(samples[2], -1, accuracy: 0.0001)
    }

    func testRejectsUnsupportedWaveFormat() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiroWaveTest-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        var data = waveData(samples: [0])
        data[24] = 0x44
        data[25] = 0xAC
        try data.write(to: url)

        XCTAssertThrowsError(try WhisperWaveDecoder.decode(url)) { error in
            XCTAssertEqual(error as? OfflineTranscriptionError, .unsupportedAudio)
        }
    }

    func testOfflineInferenceWhenExplicitlyEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let modelPath = environment["TIRO_OFFLINE_MODEL_PATH"],
              let audioPath = environment["TIRO_OFFLINE_AUDIO_PATH"]
        else {
            throw XCTSkip("Offline model integration test is opt-in")
        }

        let transcript = try await OfflineTranscriptionClient().transcribe(
            fileURL: URL(fileURLWithPath: audioPath),
            modelURL: URL(fileURLWithPath: modelPath),
            prompt: ""
        )

        XCTAssertFalse(transcript.isEmpty)
    }

    private func waveData(samples: [Int16]) -> Data {
        var data = Data()
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36) + dataSize, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(16_000), to: &data)
        append(UInt32(32_000), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(dataSize, to: &data)
        for sample in samples {
            append(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private func append(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private func append(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }
}
