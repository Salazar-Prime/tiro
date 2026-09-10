import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

enum ScreenshotCaptureMode {
    case usableScreen
    case selection
}

enum ScreenshotGeometry {
    static func sourceRect(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let displayBounds = CGRect(origin: .zero, size: screenFrame.size)
        let displayLocalRect = CGRect(
            x: visibleFrame.minX - screenFrame.minX,
            y: screenFrame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
        let clipped = displayLocalRect.intersection(displayBounds)
        return clipped.isNull ? .zero : clipped
    }
}

enum ScreenshotStorage {
    static var directoryURL: URL {
        let pictures = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
        return pictures.appendingPathComponent("Tiro screenshots", isDirectory: true)
    }

    static func prepareDirectory() throws -> URL {
        let directory = directoryURL
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    static func nextFileURL(at date: Date = Date()) throws -> URL {
        try nextFileURL(named: "Tiro Screenshot", at: date)
    }

    static func nextWireframeFileURL(at date: Date = Date()) throws -> URL {
        try nextFileURL(named: "Tiro Wireframe", at: date)
    }

    private static func nextFileURL(named prefix: String, at date: Date) throws -> URL {
        let directory = try prepareDirectory()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss.SSS"
        let filename = "\(prefix) \(formatter.string(from: date)).png"
        return directory.appendingPathComponent(filename, isDirectory: false)
    }
}

struct ScreenshotPathWrapper: Equatable {
    static let defaultValue = ScreenshotPathWrapper(
        isEnabled: true,
        prefix: "'",
        suffix: "'"
    )
    static let plain = ScreenshotPathWrapper(
        isEnabled: false,
        prefix: "",
        suffix: ""
    )

    let isEnabled: Bool
    let prefix: String
    let suffix: String

    func format(_ path: String) -> String {
        guard isEnabled else { return path }
        return "\(prefix)\(path)\(suffix)"
    }
}

enum ScreenshotLinkFormatter {
    static func link(
        for fileURL: URL,
        wrapper: ScreenshotPathWrapper = .defaultValue
    ) -> String {
        wrapper.format(fileURL.path)
    }

    static func appending(
        _ fileURLs: [URL],
        to transcript: String,
        wrapper: ScreenshotPathWrapper = .defaultValue
    ) -> String {
        guard !fileURLs.isEmpty else { return transcript }
        let links = fileURLs.map { link(for: $0, wrapper: wrapper) }
            .joined(separator: "\n")
        guard !transcript.isEmpty else { return links }
        return "\(transcript)\n\n\(links)"
    }
}

@MainActor
final class ScreenshotCaptureController {
    private let model: AppModel
    private let overlay: OverlayWindowController
    private let historyStore: TranscriptHistoryStore
    private let service = ScreenshotCaptureService()
    private var captureTask: Task<Void, Never>?

    init(
        model: AppModel,
        overlay: OverlayWindowController,
        historyStore: TranscriptHistoryStore
    ) {
        self.model = model
        self.overlay = overlay
        self.historyStore = historyStore
    }

    func capture(_ mode: ScreenshotCaptureMode) {
        guard captureTask == nil else {
            overlay.show(.screenshotError("Capture already open"))
            overlay.hide(after: 1.4)
            return
        }

        model.refreshPermissions()
        guard model.screenCaptureStatus == .granted else {
            overlay.show(.screenshotError("Enable Screen Recording"))
            overlay.hide(after: 1.8)
            model.requestScreenCapture()
            return
        }

        let targetPID = TextInsertionService.captureTargetPID()
        model.setScreenshotCaptureBusy(true)
        overlay.hide()

        captureTask = Task { [weak self] in
            guard let self else { return }
            defer {
                model.setScreenshotCaptureBusy(false)
                captureTask = nil
            }

            do {
                // Give the menu and Tiro's nonactivating overlay time to leave the frame.
                try await Task.sleep(for: .milliseconds(180))
                let fileURL = try await service.capture(mode)
                guard !Task.isCancelled else { return }
                historyStore.add(
                    ScreenshotLinkFormatter.link(
                        for: fileURL,
                        wrapper: model.screenshotPathWrapper
                    )
                )
                await deliver(fileURL, to: targetPID)
            } catch ScreenshotCaptureError.cancelled {
                overlay.hide()
            } catch ScreenshotCaptureError.permissionRequired {
                overlay.show(.screenshotError("Restart after allowing capture"))
                overlay.hide(after: 2.2)
            } catch {
                overlay.show(.screenshotError(error.localizedDescription))
                overlay.hide(after: 2.2)
            }
        }
    }

    func captureUsableScreenForTranscript() -> Task<URL?, Never>? {
        model.refreshPermissions()
        guard model.screenCaptureStatus == .granted else {
            overlay.show(.screenshotError("Enable Screen Recording"))
            overlay.hide(after: 1.6)
            return nil
        }

        return Task { [weak self] in
            guard let self else { return nil }
            do {
                return try await service.capture(.usableScreen)
            } catch {
                return nil
            }
        }
    }

    func openScreenshotsFolder() {
        do {
            let directory = try ScreenshotStorage.prepareDirectory()
            NSWorkspace.shared.open(directory)
        } catch {
            overlay.show(.screenshotError("Couldn’t open screenshot folder"))
            overlay.hide(after: 1.8)
        }
    }

    func cancel() {
        captureTask?.cancel()
        captureTask = nil
        model.setScreenshotCaptureBusy(false)
    }

    private func deliver(_ fileURL: URL, to targetPID: pid_t?) async {
        guard let targetPID else {
            showCopyResult(for: fileURL)
            return
        }

        switch await TextInsertionService.insertImage(at: fileURL, targetPID: targetPID) {
        case .pasteCommandSent:
            overlay.show(.screenshotSuccess("Screenshot pasted"))
        case .accessibilityUnavailable:
            showCopyResult(for: fileURL, message: "Saved and copied")
        case .noActiveTarget, .failed, .insertedDirectly:
            showCopyResult(for: fileURL)
        }
        overlay.hide(after: 1.6)
    }

    private func showCopyResult(for fileURL: URL, message: String = "Saved and copied") {
        if TextInsertionService.copyImage(at: fileURL) {
            overlay.show(.screenshotSuccess(message))
        } else {
            overlay.show(.screenshotError("Screenshot saved"))
        }
        overlay.hide(after: 1.6)
    }
}

@MainActor
private final class ScreenshotCaptureService {
    func capture(_ mode: ScreenshotCaptureMode) async throws -> URL {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenshotCaptureError.permissionRequired
        }

        let fileURL = try ScreenshotStorage.nextFileURL()
        switch mode {
        case .usableScreen:
            try await captureUsableScreen(to: fileURL)
        case .selection:
            try await captureSelection(to: fileURL)
        }
        return fileURL
    }

    private func captureUsableScreen(to fileURL: URL) async throws {
        guard let screen = activeScreen(),
              let displayNumber = screen.deviceDescription[
                  NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber
        else { throw ScreenshotCaptureError.screenUnavailable }

        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = availableContent.displays.first(where: {
            $0.displayID == CGDirectDisplayID(displayNumber.uint32Value)
        }) else { throw ScreenshotCaptureError.screenUnavailable }

        let sourceRect = ScreenshotGeometry.sourceRect(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            throw ScreenshotCaptureError.screenUnavailable
        }

        let excludedApplications = availableContent.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = max(Int((sourceRect.width * scale).rounded()), 1)
        configuration.height = max(Int((sourceRect.height * scale).rounded()), 1)
        configuration.showsCursor = false

        let image = try await captureImage(filter: filter, configuration: configuration)
        try writePNG(image, to: fileURL)
    }

    private func captureSelection(to fileURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", "-x", "-t", "png", fileURL.path]

        let status = try await run(process)
        guard status == 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0
        else {
            try? FileManager.default.removeItem(at: fileURL)
            throw ScreenshotCaptureError.cancelled
        }
    }

    private func captureImage(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(
                        throwing: error ?? ScreenshotCaptureError.captureFailed
                    )
                }
            }
        }
    }

    private func run(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finishedProcess in
                continuation.resume(returning: finishedProcess.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func writePNG(_ image: CGImage, to fileURL: URL) throws {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw ScreenshotCaptureError.saveFailed
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }
}

private enum ScreenshotCaptureError: LocalizedError {
    case permissionRequired
    case screenUnavailable
    case captureFailed
    case saveFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Screen Recording permission is required."
        case .screenUnavailable:
            "No screen is available to capture."
        case .captureFailed:
            "The screenshot couldn’t be captured."
        case .saveFailed:
            "The screenshot couldn’t be saved."
        case .cancelled:
            "Screenshot cancelled."
        }
    }
}
