import AppKit

@MainActor
enum TiroMenuBarIcon {
    static func make(size: CGFloat = 18) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize, flipped: false) { bounds in
            let scale = min(bounds.width, bounds.height) / 18
            let xOffset = bounds.midX - (9 * scale)
            let yOffset = bounds.midY - (9 * scale)

            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(
                    x: xOffset + (x * scale),
                    y: yOffset + (y * scale)
                )
            }

            NSColor.black.setStroke()

            let nib = NSBezierPath()
            nib.move(to: point(3.8, 12.4))
            nib.curve(
                to: point(9, 16.2),
                controlPoint1: point(3.8, 14.6),
                controlPoint2: point(6.1, 16.2)
            )
            nib.curve(
                to: point(14.2, 12.4),
                controlPoint1: point(11.9, 16.2),
                controlPoint2: point(14.2, 14.6)
            )
            nib.line(to: point(14.2, 8.5))
            nib.curve(
                to: point(13.7, 7.1),
                controlPoint1: point(14.2, 8.0),
                controlPoint2: point(14.0, 7.5)
            )
            nib.line(to: point(9, 1.35))
            nib.line(to: point(4.3, 7.1))
            nib.curve(
                to: point(3.8, 8.5),
                controlPoint1: point(4.0, 7.5),
                controlPoint2: point(3.8, 8.0)
            )
            nib.close()
            nib.lineWidth = 1.35 * scale
            nib.lineCapStyle = .round
            nib.lineJoinStyle = .round
            nib.stroke()

            let breatherHole = NSBezierPath(
                ovalIn: NSRect(
                    x: point(7.95, 7.0).x,
                    y: point(7.95, 7.0).y,
                    width: 2.1 * scale,
                    height: 2.1 * scale
                )
            )
            breatherHole.lineWidth = 1.2 * scale
            breatherHole.stroke()

            let slit = NSBezierPath()
            slit.move(to: point(9, 7.0))
            slit.line(to: point(9, 1.35))
            slit.lineWidth = 1.2 * scale
            slit.lineCapStyle = .round
            slit.stroke()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tiro"
        return image
    }
}
