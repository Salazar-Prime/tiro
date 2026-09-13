import CoreGraphics

enum WireframeScreenshotLayout {
    static func frame(imageSize: CGSize, canvasSize: CGSize) -> CGRect? {
        guard imageSize.width.isFinite, imageSize.height.isFinite,
              imageSize.width > 0, imageSize.height > 0 else { return nil }
        // Leave room for the top tool groups, left ink rail, and bottom actions.
        let available = CGRect(x: 58, y: 138, width: canvasSize.width - 70, height: canvasSize.height - 218)
        guard available.width > 0, available.height > 0 else { return nil }
        let limit = CGSize(width: min(available.width, canvasSize.width * 0.75),
                           height: min(available.height, canvasSize.height * 0.75))
        let scale = min(limit.width / imageSize.width, limit.height / imageSize.height, 1)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: available.midX - size.width / 2, y: available.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

enum WireframeCursorHintLayout {
    static func frame(pointer: CGPoint, size: CGSize, canvas: CGRect, avoiding obstacles: [CGRect]) -> CGRect? {
        let safe = canvas.insetBy(dx: 8, dy: 8)
        guard size.width <= safe.width, size.height <= safe.height else { return nil }
        let origins = [
            CGPoint(x: pointer.x + 14, y: pointer.y + 18),
            CGPoint(x: pointer.x + 14, y: pointer.y - size.height - 18),
            CGPoint(x: pointer.x - size.width - 14, y: pointer.y + 18),
            CGPoint(x: pointer.x - size.width - 14, y: pointer.y - size.height - 18),
            CGPoint(x: pointer.x - size.width / 2, y: pointer.y + 26),
            CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height - 26)
        ]
        let pointerBounds = CGRect(x: pointer.x - 7, y: pointer.y - 7, width: 14, height: 14)
        return origins.map { origin in
            CGRect(x: min(max(origin.x, safe.minX), safe.maxX - size.width),
                   y: min(max(origin.y, safe.minY), safe.maxY - size.height),
                   width: size.width, height: size.height)
        }.first { candidate in
            !candidate.intersects(pointerBounds)
                && !obstacles.contains { candidate.intersects($0.insetBy(dx: -5, dy: -5)) }
        }
    }
}
