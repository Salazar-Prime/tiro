import Foundation
import XCTest
@testable import VoiceType

@MainActor
final class TranscriptHistoryStoreTests: XCTestCase {
    func testStoresNewestFirstAndPersistsAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeTests-\(UUID().uuidString)")
        let storageURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TranscriptHistoryStore(storageURL: storageURL)
        store.add("Earlier", at: Date(timeIntervalSince1970: 10))
        store.add("Later", at: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(store.entries.map(\.text), ["Later", "Earlier"])
        XCTAssertEqual(store.latest?.text, "Later")

        let reloaded = TranscriptHistoryStore(storageURL: storageURL)
        XCTAssertEqual(reloaded.entries, store.entries)
    }

    func testDeletesIndividualEntriesAndClearsHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeTests-\(UUID().uuidString)")
        let storageURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TranscriptHistoryStore(storageURL: storageURL)
        let first = store.add("First")
        store.add("Second")

        store.delete(first)
        XCTAssertEqual(store.entries.map(\.text), ["Second"])

        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(TranscriptHistoryStore(storageURL: storageURL).entries.isEmpty)
    }
}
