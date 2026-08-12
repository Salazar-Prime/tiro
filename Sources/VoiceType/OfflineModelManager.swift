import CryptoKit
import Foundation

@MainActor
final class OfflineModelManager: ObservableObject {
    enum State: Equatable {
        case missing
        case downloading
        case ready
        case failed(String)
    }

    static let modelName = "Whisper base.en · Q5"
    static let downloadSize = "60 MB"
    static let modelFileName = "ggml-base.en-q5_1.bin"

    private static let expectedByteCount: Int64 = 59_721_011
    private static let expectedSHA256 = "4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f"
    private static let modelDownloadURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.en-q5_1.bin"
    )!

    @Published private(set) var state: State = .missing

    let modelURL: URL
    private var downloadTask: Task<Void, Never>?

    var isReady: Bool { state == .ready }

    init(storageDirectory: URL? = nil) {
        let directory = storageDirectory ?? Self.defaultStorageDirectory()
        modelURL = directory.appendingPathComponent(Self.modelFileName)
        refresh()
    }

    func refresh() {
        guard downloadTask == nil else { return }
        guard let values = try? modelURL.resourceValues(forKeys: [.fileSizeKey]),
              Int64(values.fileSize ?? 0) == Self.expectedByteCount
        else {
            state = .missing
            return
        }
        state = .ready
    }

    func download() {
        guard downloadTask == nil, !isReady else { return }
        state = .downloading

        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(
                    url: Self.modelDownloadURL,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: 600
                )
                request.setValue("Tiro/0.5", forHTTPHeaderField: "User-Agent")
                let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode)
                else {
                    throw OfflineModelError.downloadFailed
                }

                let destination = modelURL
                let expectedByteCount = Int(Self.expectedByteCount)
                let expectedSHA256 = Self.expectedSHA256
                try await Task.detached(priority: .utility) {
                    let data = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
                    guard data.count == expectedByteCount else {
                        throw OfflineModelError.invalidDownload
                    }
                    let digest = SHA256.hash(data: data)
                        .map { String(format: "%02x", $0) }
                        .joined()
                    guard digest == expectedSHA256 else {
                        throw OfflineModelError.invalidDownload
                    }

                    let fileManager = FileManager.default
                    try fileManager.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    try fileManager.moveItem(at: temporaryURL, to: destination)
                }.value

                state = .ready
            } catch is CancellationError {
                state = .missing
            } catch {
                state = .failed(error.localizedDescription)
            }
            downloadTask = nil
        }
    }

    func removeModel() {
        downloadTask?.cancel()
        downloadTask = nil
        do {
            if FileManager.default.fileExists(atPath: modelURL.path) {
                try FileManager.default.removeItem(at: modelURL)
            }
            state = .missing
        } catch {
            state = .failed("The local model could not be removed.")
        }
    }

    private static func defaultStorageDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Tiro", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }
}

enum OfflineModelError: LocalizedError, Equatable {
    case downloadFailed
    case invalidDownload

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            "The offline model download failed."
        case .invalidDownload:
            "The downloaded model did not pass verification."
        }
    }
}
