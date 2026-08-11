import Foundation

struct TranscriptHistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
}

@MainActor
final class TranscriptHistoryStore: ObservableObject {
    @Published private(set) var entries: [TranscriptHistoryEntry]

    private let storageURL: URL

    var latest: TranscriptHistoryEntry? {
        entries.first
    }

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        entries = Self.load(from: self.storageURL)
    }

    @discardableResult
    func add(_ text: String, at date: Date = Date()) -> TranscriptHistoryEntry {
        let entry = TranscriptHistoryEntry(id: UUID(), text: text, createdAt: date)
        entries.insert(entry, at: 0)
        save()
        return entry
    }

    func delete(_ entry: TranscriptHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private static func defaultStorageURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Voice Type", isDirectory: true)
            .appendingPathComponent("transcript-history.json")
    }

    private static func load(from url: URL) -> [TranscriptHistoryEntry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(
                  [TranscriptHistoryEntry].self,
                  from: data
              )
        else { return [] }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: storageURL, options: .atomic)
        } catch {
            // History remains available for this session if persistence fails.
        }
    }
}
