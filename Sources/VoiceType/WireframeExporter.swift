import AppKit
import SwiftUI

@MainActor
final class WireframeExporter {
    private struct CachedExport {
        let revision: Int
        let size: CGSize
        let isDark: Bool
        let fileURL: URL
    }

    private let pathWrapper: () -> ScreenshotPathWrapper
    private let appendImageToTranscript: (URL) -> Bool
    private let fileURLProvider: () throws -> URL
    private var cachedExport: CachedExport?

    init(
        pathWrapper: @escaping () -> ScreenshotPathWrapper,
        appendImageToTranscript: @escaping (URL) -> Bool,
        fileURLProvider: @escaping () throws -> URL = {
            try ScreenshotStorage.nextWireframeFileURL()
        }
    ) {
        self.pathWrapper = pathWrapper
        self.appendImageToTranscript = appendImageToTranscript
        self.fileURLProvider = fileURLProvider
    }

    func perform(
        _ action: WireframeExportAction,
        elements: [WireframeElement],
        revision: Int,
        size: CGSize,
        colorScheme: ColorScheme
    ) -> WireframeExportFeedback {
        guard !elements.isEmpty else {
            return WireframeExportFeedback(
                message: "Draw something before exporting",
                isError: true
            )
        }

        do {
            let fileURL = try exportedFileURL(
                elements: elements,
                revision: revision,
                size: size,
                colorScheme: colorScheme
            )

            switch action {
            case .save:
                return WireframeExportFeedback(
                    message: "Saved in Tiro screenshots",
                    isError: false
                )

            case .copyLink:
                let link = ScreenshotLinkFormatter.link(
                    for: fileURL,
                    wrapper: pathWrapper()
                )
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                guard pasteboard.setString(link, forType: .string) else {
                    return WireframeExportFeedback(
                        message: "Image saved · link couldn’t be copied",
                        isError: true
                    )
                }
                return WireframeExportFeedback(
                    message: "Saved and copied link",
                    isError: false
                )

            case .appendLink:
                guard appendImageToTranscript(fileURL) else {
                    return WireframeExportFeedback(
                        message: "Saved · start voice typing to append",
                        isError: true
                    )
                }
                return WireframeExportFeedback(
                    message: "Saved and added to this transcript",
                    isError: false
                )
            }
        } catch {
            return WireframeExportFeedback(
                message: "Wireframe image couldn’t be saved",
                isError: true
            )
        }
    }

    private func exportedFileURL(
        elements: [WireframeElement],
        revision: Int,
        size: CGSize,
        colorScheme: ColorScheme
    ) throws -> URL {
        let isDark = colorScheme == .dark
        if let cachedExport,
           cachedExport.revision == revision,
           cachedExport.size == size,
           cachedExport.isDark == isDark,
           FileManager.default.fileExists(atPath: cachedExport.fileURL.path) {
            return cachedExport.fileURL
        }

        let content = WireframeArtworkView(
            elements: elements,
            selectedTool: .rectangle,
            draftPoints: [],
            namingElementID: nil,
            hoverPoint: nil,
            showsDraft: false
        )
        .environment(\.colorScheme, colorScheme)
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { throw WireframeExportError.renderFailed }

        let fileURL = try fileURLProvider()
        try pngData.write(to: fileURL, options: .atomic)
        cachedExport = CachedExport(
            revision: revision,
            size: size,
            isDark: isDark,
            fileURL: fileURL
        )
        return fileURL
    }
}

private enum WireframeExportError: Error {
    case renderFailed
}
