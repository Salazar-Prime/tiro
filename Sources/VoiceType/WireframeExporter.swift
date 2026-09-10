import AppKit
import SwiftUI

@MainActor
final class WireframeExporter {
    private struct CachedExport {
        let revision: Int
        let isDark: Bool
        let fileURL: URL
    }

    private let pathWrapper: () -> ScreenshotPathWrapper
    private let fileURLProvider: () throws -> URL
    private let readClipboardText: () -> String?
    private let writeClipboardText: (String) -> Bool
    private var cachedExport: CachedExport?

    init(
        pathWrapper: @escaping () -> ScreenshotPathWrapper,
        fileURLProvider: @escaping () throws -> URL = {
            try ScreenshotStorage.nextWireframeFileURL()
        },
        readClipboardText: @escaping () -> String? = {
            NSPasteboard.general.string(forType: .string)
        },
        writeClipboardText: @escaping (String) -> Bool = { value in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setString(value, forType: .string)
        }
    ) {
        self.pathWrapper = pathWrapper
        self.fileURLProvider = fileURLProvider
        self.readClipboardText = readClipboardText
        self.writeClipboardText = writeClipboardText
    }

    func perform(
        _ action: WireframeExportAction,
        elements: [WireframeElement],
        revision: Int,
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
                guard writeClipboardText(link) else {
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
                let link = ScreenshotLinkFormatter.appending(
                    [fileURL],
                    to: readClipboardText() ?? "",
                    wrapper: pathWrapper()
                )
                guard writeClipboardText(link) else {
                    return WireframeExportFeedback(
                        message: "Image saved · clipboard couldn’t be updated",
                        isError: true
                    )
                }
                return WireframeExportFeedback(
                    message: "Saved and appended to clipboard",
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
        colorScheme: ColorScheme
    ) throws -> URL {
        let isDark = colorScheme == .dark
        if let cachedExport,
           cachedExport.revision == revision,
           cachedExport.isDark == isDark,
           FileManager.default.fileExists(atPath: cachedExport.fileURL.path) {
            return cachedExport.fileURL
        }

        let layout = WireframeExportLayout(elements: elements)
        let content = WireframeArtworkView(
            elements: layout.translatedElements,
            selectedTool: .rectangle,
            draftPoints: [],
            namingElementID: nil,
            hoverPoint: nil,
            showsDraft: false
        )
        .environment(\.colorScheme, colorScheme)
        .frame(width: layout.outputSize.width, height: layout.outputSize.height)

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
            isDark: isDark,
            fileURL: fileURL
        )
        return fileURL
    }
}

struct WireframeExportLayout: Equatable {
    static let padding: CGFloat = 18

    let sourceRect: CGRect
    let translatedElements: [WireframeElement]

    var outputSize: CGSize {
        sourceRect.size
    }

    init(elements: [WireframeElement]) {
        guard let firstElement = elements.first else {
            sourceRect = .zero
            translatedElements = []
            return
        }

        let contentBounds = elements.dropFirst().reduce(Self.visualBounds(for: firstElement)) {
            $0.union(Self.visualBounds(for: $1))
        }
        let paddedBounds = contentBounds.insetBy(
            dx: -Self.padding,
            dy: -Self.padding
        )
        let side = max(paddedBounds.width, paddedBounds.height)
        let square = CGRect(
            x: paddedBounds.midX - side / 2,
            y: paddedBounds.midY - side / 2,
            width: side,
            height: side
        )
        sourceRect = square
        translatedElements = elements.map { element in
            WireframeElement(
                id: element.id,
                geometry: element.geometry.offsetBy(
                    dx: -square.minX,
                    dy: -square.minY
                ),
                name: element.name
            )
        }
    }

    private static func visualBounds(for element: WireframeElement) -> CGRect {
        guard !element.name.isEmpty else { return element.geometry.bounds }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        let textSize = (element.name as NSString).size(withAttributes: attributes)
        let anchor = element.geometry.labelAnchor
        let labelBounds = CGRect(
            x: anchor.x - textSize.width / 2 - 3,
            y: anchor.y - textSize.height / 2 - 2,
            width: textSize.width + 6,
            height: textSize.height + 4
        )
        return element.geometry.bounds.union(labelBounds)
    }
}

private enum WireframeExportError: Error {
    case renderFailed
}
