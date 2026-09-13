import AppKit
import CoreGraphics
import Foundation

enum WireframeTool: String, CaseIterable, Identifiable {
    case rectangle
    case circle
    case ellipse
    case pen
    case rename
    case mobileFrame
    case browserFrame
    case dottedFrame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        case .ellipse: "Ellipse"
        case .pen: "Pen"
        case .rename: "Label"
        case .mobileFrame: "Mobile frame"
        case .browserFrame: "Browser window"
        case .dottedFrame: "Dotted frame"
        }
    }

    var symbolName: String {
        switch self {
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .ellipse: "oval"
        case .pen: "pencil.tip"
        case .rename: "character.cursor.ibeam"
        case .mobileFrame: "iphone"
        case .browserFrame: "macwindow"
        case .dottedFrame: "rectangle.dashed"
        }
    }

    var instruction: String {
        switch self {
        case .rectangle: "Click two opposite corners"
        case .circle: "Click the center, then the edge"
        case .ellipse: "Click both ends of the major axis, then set the width"
        case .pen: "Drag to draw a freeform element"
        case .rename: "Click an element border to add or change its label"
        case .mobileFrame: "Click two corners for a mobile screen"
        case .browserFrame: "Click two corners for a browser window"
        case .dottedFrame: "Click two corners for a dotted container"
        }
    }

    var actionLabel: String {
        switch self {
        case .rectangle: "Draw a rectangle"
        case .circle: "Draw a circle"
        case .ellipse: "Draw an ellipse"
        case .pen: "Draw with pen"
        case .rename: "Label a shape"
        case .mobileFrame: "Draw a mobile frame"
        case .browserFrame: "Draw a browser"
        case .dottedFrame: "Draw a dotted frame"
        }
    }
}

enum WireframeGeometry: Equatable {
    case rectangle(CGRect)
    case circle(center: CGPoint, radius: CGFloat)
    case ellipse(
        center: CGPoint,
        majorRadius: CGFloat,
        minorRadius: CGFloat,
        rotation: CGFloat
    )
    case stroke([CGPoint])
    case mobileFrame(CGRect)
    case browserFrame(CGRect)
    case dottedFrame(CGRect)
    case screenshot(CGRect)

    var bounds: CGRect {
        switch self {
        case let .rectangle(rect):
            return rect
        case let .circle(center, radius):
            return CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        case let .ellipse(center, majorRadius, minorRadius, rotation):
            let cosine = cos(rotation)
            let sine = sin(rotation)
            let halfWidth = sqrt(
                majorRadius * majorRadius * cosine * cosine
                    + minorRadius * minorRadius * sine * sine
            )
            let halfHeight = sqrt(
                majorRadius * majorRadius * sine * sine
                    + minorRadius * minorRadius * cosine * cosine
            )
            return CGRect(
                x: center.x - halfWidth,
                y: center.y - halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            )
        case let .stroke(points):
            guard let first = points.first else { return .zero }
            return points.dropFirst().reduce(
                CGRect(origin: first, size: .zero)
            ) { bounds, point in
                bounds.union(CGRect(origin: point, size: .zero))
            }
        case let .mobileFrame(rect),
             let .browserFrame(rect),
             let .dottedFrame(rect),
             let .screenshot(rect):
            return rect
        }
    }

    var labelAnchor: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> WireframeGeometry {
        switch self {
        case let .rectangle(rect):
            return .rectangle(rect.offsetBy(dx: dx, dy: dy))
        case let .circle(center, radius):
            return .circle(
                center: CGPoint(x: center.x + dx, y: center.y + dy),
                radius: radius
            )
        case let .ellipse(center, majorRadius, minorRadius, rotation):
            return .ellipse(
                center: CGPoint(x: center.x + dx, y: center.y + dy),
                majorRadius: majorRadius,
                minorRadius: minorRadius,
                rotation: rotation
            )
        case let .stroke(points):
            return .stroke(points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) })
        case let .mobileFrame(rect):
            return .mobileFrame(rect.offsetBy(dx: dx, dy: dy))
        case let .browserFrame(rect):
            return .browserFrame(rect.offsetBy(dx: dx, dy: dy))
        case let .dottedFrame(rect):
            return .dottedFrame(rect.offsetBy(dx: dx, dy: dy))
        case let .screenshot(rect):
            return .screenshot(rect.offsetBy(dx: dx, dy: dy))
        }
    }

    func borderDistance(to point: CGPoint) -> CGFloat {
        switch self {
        case let .rectangle(rect),
             let .mobileFrame(rect),
             let .browserFrame(rect),
             let .dottedFrame(rect),
             let .screenshot(rect):
            let clampedX = min(max(point.x, rect.minX), rect.maxX)
            let clampedY = min(max(point.y, rect.minY), rect.maxY)
            if rect.contains(point) {
                return min(
                    abs(point.x - rect.minX),
                    abs(point.x - rect.maxX),
                    abs(point.y - rect.minY),
                    abs(point.y - rect.maxY)
                )
            }
            return hypot(point.x - clampedX, point.y - clampedY)

        case let .circle(center, radius):
            return abs(hypot(point.x - center.x, point.y - center.y) - radius)

        case let .ellipse(center, majorRadius, minorRadius, rotation):
            guard majorRadius > 0, minorRadius > 0 else { return .greatestFiniteMagnitude }
            let deltaX = point.x - center.x
            let deltaY = point.y - center.y
            let cosine = cos(rotation)
            let sine = sin(rotation)
            let localX = deltaX * cosine + deltaY * sine
            let localY = -deltaX * sine + deltaY * cosine
            let normalizedRadius = sqrt(
                (localX * localX) / (majorRadius * majorRadius)
                    + (localY * localY) / (minorRadius * minorRadius)
            )
            return abs(normalizedRadius - 1) * min(majorRadius, minorRadius)

        case let .stroke(points):
            guard let first = points.first else { return .greatestFiniteMagnitude }
            guard points.count > 1 else {
                return hypot(point.x - first.x, point.y - first.y)
            }
            return zip(points, points.dropFirst()).reduce(.greatestFiniteMagnitude) {
                minimum, segment in
                min(
                    minimum,
                    Self.distance(
                        from: point,
                        toSegmentFrom: segment.0,
                        to: segment.1
                    )
                )
            }
        }
    }

    private static func distance(
        from point: CGPoint,
        toSegmentFrom start: CGPoint,
        to end: CGPoint
    ) -> CGFloat {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let projection = min(
            1,
            max(
                0,
                ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY)
                    / lengthSquared
            )
        )
        let closest = CGPoint(
            x: start.x + projection * deltaX,
            y: start.y + projection * deltaY
        )
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}

struct WireframeElement: Identifiable, Equatable {
    let id: UUID
    var geometry: WireframeGeometry
    var name: String
    var color: WireframeColor
    var image: NSImage?

    init(
        id: UUID = UUID(), geometry: WireframeGeometry,
        name: String = "", color: WireframeColor = .ink, image: NSImage? = nil
    ) {
        self.id = id
        self.geometry = geometry
        self.name = name
        self.color = color
        self.image = image
    }

    var labelBounds: CGRect? {
        guard !name.isEmpty else { return nil }
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 12) } ?? font
        let size = (name as NSString).size(withAttributes: [.font: rounded])
        let anchor = geometry.labelAnchor
        return CGRect(x: anchor.x - size.width / 2 - 4, y: anchor.y - size.height / 2 - 3,
                      width: size.width + 8, height: size.height + 6)
    }
}

enum WireframeGeometryFactory {
    static func rectangle(from first: CGPoint, to second: CGPoint) -> WireframeGeometry {
        .rectangle(
            CGRect(
                x: min(first.x, second.x),
                y: min(first.y, second.y),
                width: abs(second.x - first.x),
                height: abs(second.y - first.y)
            )
        )
    }

    static func circle(center: CGPoint, edge: CGPoint) -> WireframeGeometry {
        .circle(
            center: center,
            radius: hypot(edge.x - center.x, edge.y - center.y)
        )
    }

    static func ellipse(
        majorAxisStart: CGPoint,
        majorAxisEnd: CGPoint,
        minorAxisPoint: CGPoint
    ) -> WireframeGeometry {
        let axisX = majorAxisEnd.x - majorAxisStart.x
        let axisY = majorAxisEnd.y - majorAxisStart.y
        let axisLength = hypot(axisX, axisY)
        let center = CGPoint(
            x: (majorAxisStart.x + majorAxisEnd.x) / 2,
            y: (majorAxisStart.y + majorAxisEnd.y) / 2
        )
        let majorRadius = axisLength / 2
        let perpendicularDistance: CGFloat
        if axisLength > 0 {
            perpendicularDistance = abs(
                axisX * (majorAxisStart.y - minorAxisPoint.y)
                    - (majorAxisStart.x - minorAxisPoint.x) * axisY
            ) / axisLength
        } else {
            perpendicularDistance = 0
        }
        return .ellipse(
            center: center,
            majorRadius: majorRadius,
            minorRadius: min(perpendicularDistance, majorRadius),
            rotation: atan2(axisY, axisX)
        )
    }

    static func mobileFrame(from first: CGPoint, to second: CGPoint) -> WireframeGeometry {
        .mobileFrame(rectangleBounds(from: first, to: second))
    }

    static func browserFrame(from first: CGPoint, to second: CGPoint) -> WireframeGeometry {
        .browserFrame(rectangleBounds(from: first, to: second))
    }

    static func dottedFrame(from first: CGPoint, to second: CGPoint) -> WireframeGeometry {
        .dottedFrame(rectangleBounds(from: first, to: second))
    }

    private static func rectangleBounds(from first: CGPoint, to second: CGPoint) -> CGRect {
        CGRect(
            x: min(first.x, second.x),
            y: min(first.y, second.y),
            width: abs(second.x - first.x),
            height: abs(second.y - first.y)
        )
    }
}

@MainActor
final class WireframeCanvasModel: ObservableObject {
    @Published private(set) var elements: [WireframeElement] = []
    @Published private(set) var selectedTool: WireframeTool = .mobileFrame
    @Published private(set) var draftPoints: [CGPoint] = []
    @Published private(set) var namingElementID: UUID?
    @Published var namingText = ""
    @Published private(set) var namingSkipIsArmed = false
    @Published private(set) var contentRevision = 0
    @Published private(set) var isPinned = false
    @Published private(set) var selectedColor: WireframeColor = .ink

    var canUndo: Bool {
        !elements.isEmpty
    }

    var canClearAll: Bool {
        !elements.isEmpty || !draftPoints.isEmpty
    }

    var statusText: String {
        if namingElementID != nil {
            if namingSkipIsArmed && namingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Label · Press Return again to leave this element unnamed"
            }
            return "Label · Type in gold · Return saves · Return twice skips"
        }

        switch (selectedTool, draftPoints.count) {
        case (.rectangle, 1): return "Rectangle · Click the opposite corner"
        case (.circle, 1): return "Circle · Click the circle edge"
        case (.ellipse, 1): return "Ellipse · Click the other end of the major axis"
        case (.ellipse, 2): return "Ellipse · Click to set the minor radius"
        case (.mobileFrame, 1): return "Mobile frame · Click the opposite corner"
        case (.browserFrame, 1): return "Browser window · Click the opposite corner"
        case (.dottedFrame, 1): return "Dotted frame · Click the opposite corner"
        default: return "\(selectedTool.title) · \(selectedTool.instruction)"
        }
    }

    var cursorHint: String? {
        guard namingElementID == nil else { return nil }
        switch selectedTool {
        case .rectangle, .mobileFrame, .browserFrame, .dottedFrame:
            return draftPoints.isEmpty ? "Click first point" : "Click second point"
        case .circle: return draftPoints.isEmpty ? "Click center" : "Click edge"
        case .ellipse:
            return ["Click first point", "Click axis end", "Click width"][min(draftPoints.count, 2)]
        case .pen: return draftPoints.isEmpty ? "Drag to draw" : nil
        case .rename: return "Click border to label"
        }
    }

    func insertScreenshot(_ image: NSImage, canvasSize: CGSize) {
        guard let rect = WireframeScreenshotLayout.frame(imageSize: image.size, canvasSize: canvasSize) else { return }
        finishPendingName()
        cancelDraft()
        elements.append(WireframeElement(geometry: .screenshot(rect), image: image))
        contentRevision += 1
    }

    func togglePin() {
        isPinned.toggle()
    }

    func selectColor(_ color: WireframeColor) {
        selectedColor = color
        if let index = elements.firstIndex(where: { $0.id == namingElementID }),
           elements[index].color != color {
            elements[index].color = color
            contentRevision += 1
        }
        finishPendingName()
    }

    func selectTool(_ tool: WireframeTool) {
        finishPendingName()
        selectedTool = tool
        draftPoints = []
    }

    func handleClick(at point: CGPoint) {
        if namingElementID != nil {
            finishPendingName()
            return
        }

        switch selectedTool {
        case .rectangle:
            if let first = draftPoints.first {
                let geometry = WireframeGeometryFactory.rectangle(from: first, to: point)
                guard geometry.bounds.width >= 4, geometry.bounds.height >= 4 else { return }
                addElement(geometry)
            } else {
                draftPoints = [point]
            }

        case .circle:
            if let center = draftPoints.first {
                let geometry = WireframeGeometryFactory.circle(center: center, edge: point)
                guard geometry.bounds.width >= 8 else { return }
                addElement(geometry)
            } else {
                draftPoints = [point]
            }

        case .ellipse:
            if draftPoints.count < 2 {
                if let first = draftPoints.first,
                   hypot(point.x - first.x, point.y - first.y) < 8 {
                    return
                }
                draftPoints.append(point)
            } else {
                let geometry = WireframeGeometryFactory.ellipse(
                    majorAxisStart: draftPoints[0],
                    majorAxisEnd: draftPoints[1],
                    minorAxisPoint: point
                )
                guard case let .ellipse(_, _, minorRadius, _) = geometry,
                      minorRadius >= 4
                else { return }
                addElement(geometry)
            }

        case .pen:
            break

        case .rename:
            guard let element = elements.last(where: {
                $0.geometry.borderDistance(to: point) <= 9
            }) else { return }
            beginNaming(element)

        case .mobileFrame, .browserFrame, .dottedFrame:
            if let first = draftPoints.first {
                let geometry: WireframeGeometry
                let minimumSize: CGSize
                switch selectedTool {
                case .mobileFrame:
                    geometry = WireframeGeometryFactory.mobileFrame(from: first, to: point)
                    minimumSize = CGSize(width: 48, height: 80)
                case .browserFrame:
                    geometry = WireframeGeometryFactory.browserFrame(from: first, to: point)
                    minimumSize = CGSize(width: 100, height: 70)
                case .dottedFrame:
                    geometry = WireframeGeometryFactory.dottedFrame(from: first, to: point)
                    minimumSize = CGSize(width: 40, height: 40)
                default:
                    return
                }
                guard geometry.bounds.width >= minimumSize.width,
                      geometry.bounds.height >= minimumSize.height
                else { return }
                addElement(geometry)
            } else {
                draftPoints = [point]
            }
        }
    }

    func beginPenStroke(at point: CGPoint) {
        guard selectedTool == .pen, namingElementID == nil else { return }
        draftPoints = [point]
    }

    func continuePenStroke(at point: CGPoint) {
        guard selectedTool == .pen,
              namingElementID == nil,
              let previous = draftPoints.last,
              hypot(point.x - previous.x, point.y - previous.y) >= 1.5
        else { return }
        draftPoints.append(point)
    }

    func endPenStroke(at point: CGPoint) {
        guard selectedTool == .pen, namingElementID == nil else { return }
        continuePenStroke(at: point)
        guard draftPoints.count >= 2,
              WireframeGeometry.stroke(draftPoints).bounds.width >= 2
                || WireframeGeometry.stroke(draftPoints).bounds.height >= 2
        else {
            draftPoints = []
            return
        }
        addElement(.stroke(draftPoints))
    }

    func submitName() {
        guard let namingElementID else { return }
        let trimmedName = namingText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty, !namingSkipIsArmed {
            namingSkipIsArmed = true
            return
        }

        if let index = elements.firstIndex(where: { $0.id == namingElementID }) {
            updateName(trimmedName, at: index)
        }
        finishNaming()
    }

    func cancelNaming() {
        finishNaming()
    }

    func cancelDraft() {
        draftPoints = []
    }

    /// Returns false only when there is no in-progress action to escape.
    @discardableResult
    func handleEscape() -> Bool {
        if !draftPoints.isEmpty {
            cancelDraft()
            return true
        }
        if namingElementID != nil {
            cancelNaming()
            return true
        }
        return false
    }

    var hasUnsavedName: Bool {
        guard let element = elements.first(where: { $0.id == namingElementID }) else {
            return false
        }
        return namingText.trimmingCharacters(in: .whitespacesAndNewlines) != element.name
    }

    func undoLast() {
        guard let removed = elements.popLast() else { return }
        contentRevision += 1
        if removed.id == namingElementID {
            finishNaming()
        }
        draftPoints = []
    }

    func clearAll() {
        let hadElements = !elements.isEmpty
        elements.removeAll()
        draftPoints = []
        finishNaming()
        if hadElements {
            contentRevision += 1
        }
    }

    func finishPendingName() {
        guard let namingElementID else { return }
        let trimmedName = namingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = elements.firstIndex(where: { $0.id == namingElementID }) {
            updateName(trimmedName, at: index)
        }
        finishNaming()
    }

    private func addElement(_ geometry: WireframeGeometry) {
        let element = WireframeElement(geometry: geometry, color: selectedColor)
        elements.append(element)
        contentRevision += 1
        draftPoints = []
        beginNaming(element)
    }

    private func beginNaming(_ element: WireframeElement) {
        namingElementID = element.id
        namingText = element.name
        selectedColor = element.color
        namingSkipIsArmed = false
    }

    private func finishNaming() {
        namingElementID = nil
        namingText = ""
        namingSkipIsArmed = false
    }

    private func updateName(_ name: String, at index: Int) {
        guard elements[index].name != name else { return }
        elements[index].name = name
        contentRevision += 1
    }
}

enum WireframePanelGeometry {
    static func frame(in visibleFrame: CGRect) -> CGRect {
        let desiredSide = max(420, visibleFrame.width / 3)
        let side = min(desiredSide, visibleFrame.height - 36)
        return CGRect(
            x: visibleFrame.maxX - side - 18,
            y: visibleFrame.midY - side / 2,
            width: side,
            height: side
        )
    }
}
