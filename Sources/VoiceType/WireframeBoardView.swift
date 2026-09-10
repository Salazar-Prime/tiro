import SwiftUI

enum WireframeExportAction {
    case save
    case copyLink
    case appendLink
}

struct WireframeExportFeedback {
    let message: String
    let isError: Bool
}

struct WireframeBoardView: View {
    @ObservedObject var model: WireframeCanvasModel
    let onExport: (WireframeExportAction, CGSize, ColorScheme) -> WireframeExportFeedback
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var nameFieldIsFocused: Bool
    @State private var hoverPoint: CGPoint?
    @State private var exportFeedback: WireframeExportFeedback?
    @State private var feedbackTask: Task<Void, Never>?

    private let drawingTools: [WireframeTool] = [
        .rectangle,
        .circle,
        .ellipse,
        .pen,
        .rename
    ]

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WireframeArtworkView(
                    elements: model.elements,
                    selectedTool: model.selectedTool,
                    draftPoints: model.draftPoints,
                    namingElementID: model.namingElementID,
                    hoverPoint: hoverPoint,
                    showsDraft: true
                )
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case let .active(location): hoverPoint = location
                    case .ended: hoverPoint = nil
                    }
                }
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            model.handleClick(at: value.location)
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard model.selectedTool == .pen else { return }
                            if model.draftPoints.isEmpty {
                                model.beginPenStroke(at: value.startLocation)
                            }
                            model.continuePenStroke(at: value.location)
                        }
                        .onEnded { value in
                            model.endPenStroke(at: value.location)
                        }
                )
                .accessibilityLabel("Wireframe drawing canvas")
                .accessibilityHint(model.statusText)

                if let element = namingElement {
                    nameField(for: element, in: proxy.size)
                }

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        drawingToolbar
                        Spacer(minLength: 8)
                        exportToolbar(canvasSize: proxy.size)
                    }
                    .padding(.top, 12)

                    Spacer()

                    statusChip
                        .allowsHitTesting(false)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(palette.ink.opacity(0.16), lineWidth: 0.75)
        }
        .padding(10)
        .onChange(of: model.namingElementID) { _, newValue in
            guard newValue != nil else {
                nameFieldIsFocused = false
                return
            }
            Task { @MainActor in
                nameFieldIsFocused = true
            }
        }
        .onExitCommand {
            if model.namingElementID != nil {
                model.finishPendingName()
            } else if !model.draftPoints.isEmpty {
                model.cancelDraft()
            } else {
                onClose()
            }
        }
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private var drawingToolbar: some View {
        HStack(spacing: 2) {
            ForEach(drawingTools) { tool in
                toolButton(tool)
            }

            Menu {
                Button {
                    model.selectTool(.mobileFrame)
                } label: {
                    Label("Mobile frame", systemImage: "iphone")
                }
                Button {
                    model.selectTool(.browserFrame)
                } label: {
                    Label("Browser window", systemImage: "macwindow")
                }
            } label: {
                Image(systemName: frameToolIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(frameToolIsSelected ? palette.aqua : palette.ink.opacity(0.72))
                    .background {
                        if frameToolIsSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(palette.aqua.opacity(0.13))
                        }
                    }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .simultaneousGesture(
                TapGesture().onEnded {
                    model.finishPendingName()
                }
            )
            .help("Add a mobile frame or browser window")
            .accessibilityLabel("Frame options")

            toolbarDivider

            Button {
                model.finishPendingName()
                model.undoLast()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(palette.ink.opacity(model.canUndo ? 0.72 : 0.25))
            }
            .buttonStyle(.plain)
            .disabled(!model.canUndo)
            .help("Undo last element")
            .accessibilityLabel("Undo last element")
        }
        .modifier(WireframeToolbarChrome(palette: palette, colorScheme: colorScheme))
    }

    private func toolButton(_ tool: WireframeTool) -> some View {
        Button {
            model.selectTool(tool)
        } label: {
            Image(systemName: tool.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(
                    model.selectedTool == tool ? palette.aqua : palette.ink.opacity(0.72)
                )
                .background {
                    if model.selectedTool == tool {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(palette.aqua.opacity(0.13))
                    }
                }
        }
        .buttonStyle(.plain)
        .help("\(tool.title): \(tool.instruction)")
        .accessibilityLabel(tool.title)
    }

    private func exportToolbar(canvasSize: CGSize) -> some View {
        HStack(spacing: 2) {
            exportButton(
                action: .save,
                icon: "square.and.arrow.down",
                label: "Save image",
                canvasSize: canvasSize
            )
            exportButton(
                action: .copyLink,
                icon: "doc.on.doc",
                label: "Copy link",
                canvasSize: canvasSize
            )
            Button {
                performExport(.appendLink, canvasSize: canvasSize)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "link")
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 7, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(palette.surface, palette.aqua)
                        .offset(x: 2, y: 2)
                }
                .font(.system(size: 12.5, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(palette.ink.opacity(model.elements.isEmpty ? 0.25 : 0.72))
            }
            .buttonStyle(.plain)
            .disabled(model.elements.isEmpty)
            .help("Append link to the active voice transcript")
            .accessibilityLabel("Append link to transcript")

            toolbarDivider

            Button {
                model.finishPendingName()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11.5, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(palette.ink.opacity(0.64))
            }
            .buttonStyle(.plain)
            .help("Close Wireframe Board")
            .accessibilityLabel("Close Wireframe Board")
        }
        .modifier(WireframeToolbarChrome(palette: palette, colorScheme: colorScheme))
    }

    private func exportButton(
        action: WireframeExportAction,
        icon: String,
        label: String,
        canvasSize: CGSize
    ) -> some View {
        Button {
            performExport(action, canvasSize: canvasSize)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(palette.ink.opacity(model.elements.isEmpty ? 0.25 : 0.72))
        }
        .buttonStyle(.plain)
        .disabled(model.elements.isEmpty)
        .help(label)
        .accessibilityLabel(label)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(palette.ink.opacity(0.12))
            .frame(width: 1, height: 17)
            .padding(.horizontal, 2)
    }

    private var statusChip: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(exportFeedback?.message ?? model.statusText)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.68))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .frame(height: 27)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(palette.ink.opacity(0.12), lineWidth: 0.75)
        }
    }

    private var statusColor: Color {
        if let exportFeedback {
            return exportFeedback.isError ? palette.danger : palette.aqua
        }
        return model.namingElementID == nil ? palette.aqua : palette.coral
    }

    private var frameToolIsSelected: Bool {
        model.selectedTool == .mobileFrame || model.selectedTool == .browserFrame
    }

    private var frameToolIcon: String {
        switch model.selectedTool {
        case .mobileFrame: "iphone"
        case .browserFrame: "macwindow"
        default: "rectangle.on.rectangle"
        }
    }

    private var namingElement: WireframeElement? {
        guard let namingElementID = model.namingElementID else { return nil }
        return model.elements.first(where: { $0.id == namingElementID })
    }

    private func nameField(for element: WireframeElement, in size: CGSize) -> some View {
        let fieldWidth = min(max(element.geometry.bounds.width - 16, 150), 230)
        let anchor = element.geometry.labelAnchor
        let position = CGPoint(
            x: min(max(anchor.x, fieldWidth / 2 + 12), size.width - fieldWidth / 2 - 12),
            y: min(max(anchor.y, 88), size.height - 48)
        )

        return TextField(
            model.namingSkipIsArmed ? "Return again to skip" : "Name this element",
            text: $model.namingText
        )
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(palette.coral)
        .tint(palette.coral)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .frame(width: fieldWidth, height: 30)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.surface.opacity(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.coral.opacity(0.8), lineWidth: 1.25)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
        .focused($nameFieldIsFocused)
        .onSubmit {
            model.submitName()
            if model.namingElementID != nil {
                Task { @MainActor in
                    nameFieldIsFocused = true
                }
            }
        }
        .position(position)
        .accessibilityLabel("Element name")
    }

    private func performExport(_ action: WireframeExportAction, canvasSize: CGSize) {
        model.finishPendingName()
        exportFeedback = onExport(action, canvasSize, colorScheme)
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            exportFeedback = nil
        }
    }
}

struct WireframeArtworkView: View {
    let elements: [WireframeElement]
    let selectedTool: WireframeTool
    let draftPoints: [CGPoint]
    let namingElementID: UUID?
    let hoverPoint: CGPoint?
    let showsDraft: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        Canvas { context, size in
            drawGrid(in: &context, size: size)

            for element in elements {
                let isBeingNamed = element.id == namingElementID
                context.stroke(
                    path(for: element.geometry),
                    with: .color(isBeingNamed ? palette.aqua : palette.ink.opacity(0.82)),
                    style: StrokeStyle(
                        lineWidth: isBeingNamed ? 2.25 : 1.65,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                if !element.name.isEmpty, !isBeingNamed {
                    context.draw(
                        Text(element.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.coral),
                        at: element.geometry.labelAnchor
                    )
                }
            }

            if showsDraft {
                drawDraft(in: &context)
            }
        }
        .background(palette.surface)
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 18
        let dotColor = palette.ink.opacity(colorScheme == .dark ? 0.18 : 0.16)
        var x = spacing
        while x < size.width {
            var y = spacing
            while y < size.height {
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 0.85, y: y - 0.85, width: 1.7, height: 1.7)),
                    with: .color(dotColor)
                )
                y += spacing
            }
            x += spacing
        }
    }

    private func drawDraft(in context: inout GraphicsContext) {
        guard let first = draftPoints.first else { return }

        let guideStyle = StrokeStyle(
            lineWidth: 1.4,
            lineCap: .round,
            lineJoin: .round,
            dash: [5, 4]
        )
        let previewPoint = hoverPoint ?? draftPoints.last ?? first

        switch selectedTool {
        case .rectangle:
            drawPreview(
                WireframeGeometryFactory.rectangle(from: first, to: previewPoint),
                in: &context,
                style: guideStyle
            )

        case .circle:
            drawPreview(
                WireframeGeometryFactory.circle(center: first, edge: previewPoint),
                in: &context,
                style: guideStyle
            )

        case .ellipse:
            if draftPoints.count == 1 {
                context.stroke(
                    line(from: first, to: previewPoint),
                    with: .color(palette.coral.opacity(0.9)),
                    style: guideStyle
                )
            } else {
                let second = draftPoints[1]
                context.stroke(
                    line(from: first, to: second),
                    with: .color(palette.coral.opacity(0.72)),
                    style: guideStyle
                )
                drawPreview(
                    WireframeGeometryFactory.ellipse(
                        majorAxisStart: first,
                        majorAxisEnd: second,
                        minorAxisPoint: previewPoint
                    ),
                    in: &context,
                    style: guideStyle
                )
            }

        case .pen:
            context.stroke(
                path(for: .stroke(draftPoints)),
                with: .color(palette.aqua.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )

        case .mobileFrame:
            drawPreview(
                WireframeGeometryFactory.mobileFrame(from: first, to: previewPoint),
                in: &context,
                style: guideStyle
            )

        case .browserFrame:
            drawPreview(
                WireframeGeometryFactory.browserFrame(from: first, to: previewPoint),
                in: &context,
                style: guideStyle
            )

        case .rename:
            break
        }

        for point in draftPoints {
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                with: .color(palette.coral)
            )
        }
    }

    private func drawPreview(
        _ geometry: WireframeGeometry,
        in context: inout GraphicsContext,
        style: StrokeStyle
    ) {
        context.stroke(
            path(for: geometry),
            with: .color(palette.aqua.opacity(0.9)),
            style: style
        )
    }

    private func path(for geometry: WireframeGeometry) -> Path {
        switch geometry {
        case let .rectangle(rect):
            return Path(rect)

        case let .circle(center, radius):
            return Path(
                ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )

        case let .ellipse(center, majorRadius, minorRadius, rotation):
            var path = Path()
            let segmentCount = 72
            for index in 0...segmentCount {
                let angle = CGFloat(index) / CGFloat(segmentCount) * .pi * 2
                let localX = majorRadius * cos(angle)
                let localY = minorRadius * sin(angle)
                let point = CGPoint(
                    x: center.x + localX * cos(rotation) - localY * sin(rotation),
                    y: center.y + localX * sin(rotation) + localY * cos(rotation)
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path

        case let .stroke(points):
            var path = Path()
            guard let first = points.first else { return path }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path

        case let .mobileFrame(rect):
            return mobileFramePath(in: rect)

        case let .browserFrame(rect):
            return browserFramePath(in: rect)
        }
    }

    private func mobileFramePath(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius = min(28, min(rect.width, rect.height) * 0.11)
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let islandWidth = min(54, rect.width * 0.34)
        let islandHeight = min(12, max(7, rect.height * 0.035))
        let islandRect = CGRect(
            x: rect.midX - islandWidth / 2,
            y: rect.minY + max(9, rect.height * 0.035),
            width: islandWidth,
            height: islandHeight
        )
        path.addRoundedRect(
            in: islandRect,
            cornerSize: CGSize(width: islandHeight / 2, height: islandHeight / 2)
        )

        let homeWidth = min(68, rect.width * 0.38)
        path.addRoundedRect(
            in: CGRect(
                x: rect.midX - homeWidth / 2,
                y: rect.maxY - max(12, rect.height * 0.045),
                width: homeWidth,
                height: 3
            ),
            cornerSize: CGSize(width: 1.5, height: 1.5)
        )
        return path
    }

    private func browserFramePath(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius = min(14, min(rect.width, rect.height) * 0.08)
        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        let barHeight = min(42, max(28, rect.height * 0.14))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + barHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + barHeight))

        let dotRadius = min(3.5, barHeight * 0.09)
        for index in 0..<3 {
            let center = CGPoint(
                x: rect.minX + 15 + CGFloat(index) * 12,
                y: rect.minY + barHeight / 2
            )
            path.addEllipse(
                in: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
            )
        }

        let addressRect = CGRect(
            x: rect.minX + 55,
            y: rect.minY + barHeight * 0.27,
            width: max(0, rect.width - 70),
            height: barHeight * 0.46
        )
        if addressRect.width > 16 {
            path.addRoundedRect(
                in: addressRect,
                cornerSize: CGSize(width: addressRect.height / 2, height: addressRect.height / 2)
            )
        }
        return path
    }

    private func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct WireframeToolbarChrome: ViewModifier {
    let palette: VoiceTypePalette
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(5)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.surface.opacity(colorScheme == .dark ? 0.72 : 0.78))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(palette.ink.opacity(0.14), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
            .fixedSize()
    }
}
