import SwiftUI

enum WireframeExportAction: String {
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
    @ObservedObject var exporter: WireframeExporter
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var nameFieldIsFocused: Bool
    @State private var hoverPoint: CGPoint?
    @State private var exportFeedback: WireframeExportFeedback?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var feedbackLabel: String?
    @State private var penGestureIsActive = false
    @State private var isOpeningPreview = false

    private let drawingTools: [WireframeTool] = [
        .rectangle,
        .circle,
        .ellipse,
        .pen
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
                    showsDraft: true,
                    drawingColor: model.selectedColor
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
                            if !penGestureIsActive {
                                penGestureIsActive = true
                                model.beginPenStroke(at: value.startLocation)
                            }
                            model.continuePenStroke(at: value.location)
                        }
                        .onEnded { value in
                            model.endPenStroke(at: value.location)
                            penGestureIsActive = false
                        }
                )
                .accessibilityLabel("Wireframe drawing canvas")
                .accessibilityHint(model.statusText)

                if let element = namingElement {
                    nameField(for: element, in: proxy.size)
                }

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 4) {
                        drawingToolbar.wireframeControlBounds()
                        insertToolbar(canvasSize: proxy.size, showsTitle: proxy.size.width >= 500)
                            .wireframeControlBounds()
                        Spacer(minLength: 0)
                        windowControls.wireframeControlBounds()
                    }
                    .padding(.horizontal, -6)
                    .padding(.top, 12)

                    Spacer()

                    VStack(spacing: 8) {
                        if let feedbackLabel {
                            Text(exportFeedback?.isError == true ? exportFeedback?.message ?? feedbackLabel : feedbackLabel)
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(exportFeedback?.isError == true ? palette.danger : palette.ink)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .wireframeControlBounds()
                                .allowsHitTesting(false)
                        }
                        exportToolbar.wireframeControlBounds()
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 12)

                colorToolbar
                    .wireframeControlBounds()
                    .position(x: 30, y: max(222, proxy.size.height / 2))

            }
        }
        .overlayPreferenceValue(WireframeControlAnchors.self) { anchors in
            GeometryReader { proxy in
                cursorHint(in: proxy.size, controls: anchors.map { proxy[$0] })
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
        .onExitCommand(perform: escape)
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private var drawingToolbar: some View {
        HStack(spacing: 2) {
            ForEach(drawingTools) { tool in
                toolButton(tool)
            }

            toolbarDivider
            toolButton(.rename)

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

            Button {
                model.clearAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(
                        model.canClearAll ? palette.danger.opacity(0.78) : palette.ink.opacity(0.25)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.canClearAll)
            .help("Clear all")
            .accessibilityLabel("Clear all wireframe elements")
        }
        .modifier(WireframeToolbarDroplet(
            selectedID: frameToolIsSelected ? "frames" : model.selectedTool.rawValue,
            label: frameToolIsSelected ? nil : model.selectedTool.actionLabel,
            palette: palette, reduceMotion: reduceMotion
        ))
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
        }
        .buttonStyle(.plain)
        .help("\(tool.title): \(tool.instruction)")
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(model.selectedTool == tool ? .isSelected : [])
        .wireframeToolbarAnchor(tool.rawValue)
    }

    private var currentVersionIsSaved: Bool {
        !model.hasUnsavedName
            && exporter.savedFileURL(revision: model.contentRevision, colorScheme: colorScheme) != nil
    }

    private func insertToolbar(canvasSize: CGSize, showsTitle: Bool) -> some View {
        HStack(spacing: 4) {
            if showsTitle {
                Text("Insert")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.65))
                    .padding(.horizontal, 4)
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
                Button {
                    model.selectTool(.dottedFrame)
                } label: {
                    Label("Dotted frame", systemImage: "rectangle.dashed")
                }
            } label: {
                Image(systemName: frameToolIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(frameToolIsSelected ? palette.aqua : palette.ink.opacity(0.72))
                    .background {
                        if frameToolIsSelected {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(palette.aqua.opacity(0.13))
                        }
                    }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
            .fixedSize()
            .simultaneousGesture(
                TapGesture().onEnded {
                    model.finishPendingName()
                }
            )
            .help("Add a mobile frame, browser window, or dotted frame")
            .accessibilityLabel("Frame options")
            .wireframeToolbarAnchor("frames")

            Button {
                insertLatestScreenshot(canvasSize: canvasSize)
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(palette.ink.opacity(0.72))
            }
            .buttonStyle(.plain)
            .help("Insert the latest Tiro screenshot behind your drawing")
            .accessibilityLabel("Insert last screenshot")
        }
        .modifier(WireframeToolbarChrome(palette: palette, colorScheme: colorScheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Insert tools")
    }

    private var exportToolbar: some View {
        HStack(spacing: 2) {
            Button(action: saveOrOpen) {
                exportLabel(
                    icon: currentVersionIsSaved ? "arrow.up.forward.square" : "square.and.arrow.down",
                    title: currentVersionIsSaved ? "Open" : "Save"
                )
            }
            .buttonStyle(.plain)
            .disabled(model.elements.isEmpty || isOpeningPreview)
            .help(currentVersionIsSaved ? "Open saved image in Preview" : "Save image")
            .accessibilityLabel(currentVersionIsSaved ? "Open in Preview" : "Save image")

            toolbarDivider
            Button { performExport(.copyLink) } label: {
                exportLabel(icon: "doc.on.doc", title: "Copy link")
            }
            .buttonStyle(.plain)
            .disabled(model.elements.isEmpty)
            .help("Save and copy the image link")
            .accessibilityLabel("Copy link")

            toolbarDivider
            Button { performExport(.appendLink) } label: {
                exportLabel(icon: "link.badge.plus", title: "Append link")
            }
            .buttonStyle(.plain)
            .disabled(model.elements.isEmpty)
            .help("Save and append the link to the current clipboard text")
            .accessibilityLabel("Append link to clipboard")
        }
        .modifier(WireframeToolbarChrome(palette: palette, colorScheme: colorScheme))
    }

    private func exportLabel(icon: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(height: 24)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .frame(width: 66, height: 44)
        .foregroundStyle(palette.ink.opacity(model.elements.isEmpty ? 0.3 : 0.75))
        .contentShape(Rectangle())
    }

    private var windowControls: some View {
        HStack(spacing: 2) {
            Button {
                model.finishPendingName()
                model.togglePin()
                showFeedback(
                    WireframeExportFeedback(message: model.isPinned ? "Board pinned" : "Board unpinned", isError: false),
                    label: model.isPinned ? "Pinned" : "Unpinned"
                )
            } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(model.isPinned ? palette.aqua : palette.ink.opacity(0.64))
                    .background {
                        if model.isPinned {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(palette.aqua.opacity(0.13))
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "Unpin and hide when focus changes" : "Keep board visible")
            .accessibilityLabel(model.isPinned ? "Unpin Wireframe Board" : "Pin Wireframe Board")

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

    private func insertLatestScreenshot(canvasSize: CGSize) {
        do {
            guard let url = try ScreenshotStorage.latestScreenshotURL() else {
                showFeedback(.init(message: "No Tiro screenshots yet", isError: true),
                             label: "No screenshot")
                return
            }
            // Hold the image in memory so later edits/deletion of the source
            // cannot change the board or its export.
            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data), image.isValid else {
                showFeedback(.init(message: "The latest screenshot couldn’t be read", isError: true),
                             label: "Couldn’t insert")
                return
            }
            model.insertScreenshot(image, canvasSize: canvasSize)
            showFeedback(.init(message: "Screenshot inserted", isError: false),
                         label: "Screenshot inserted")
        } catch {
            showFeedback(.init(message: "Couldn’t read Tiro screenshots", isError: true),
                         label: "Couldn’t insert")
        }
    }

    @ViewBuilder
    private func cursorHint(in size: CGSize, controls: [CGRect]) -> some View {
        if let pointer = hoverPoint, let hint = model.cursorHint,
           !controls.contains(where: { $0.contains(pointer) }) {
            let font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
            let textSize = (hint as NSString).size(withAttributes: [.font: font])
            let hintSize = CGSize(width: ceil(textSize.width) + 24, height: 25)
            let labels = model.elements.compactMap(\.labelBounds)
            if let frame = WireframeCursorHintLayout.frame(
                pointer: pointer, size: hintSize, canvas: CGRect(origin: .zero, size: size),
                avoiding: labels + controls
            ) {
                Text(hint)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.ink.opacity(0.82))
                    .frame(width: hintSize.width, height: hintSize.height)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.aqua.opacity(0.22), lineWidth: 0.65) }
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(palette.ink.opacity(0.12))
            .frame(width: 1, height: 17)
            .padding(.horizontal, 2)
    }

    private var colorToolbar: some View {
        VStack(spacing: 7) {
            Text("Ink")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.68))
                .padding(.top, 3)
            ForEach(WireframeColor.allCases) { color in
                Button {
                    model.selectColor(color)
                } label: {
                    Circle()
                        .fill(color.color(in: colorScheme))
                        .frame(width: 17, height: 17)
                        .overlay {
                            if model.selectedColor == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(palette.surface)
                            }
                        }
                        .frame(width: 27, height: 27)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("\(color.title) ink · also recolors the element being labeled")
                .accessibilityLabel("\(color.title) ink")
                .accessibilityAddTraits(model.selectedColor == color ? .isSelected : [])
            }
        }
        .modifier(WireframeToolbarChrome(palette: palette, colorScheme: colorScheme))
    }

    private var frameToolIsSelected: Bool {
        model.selectedTool == .mobileFrame
            || model.selectedTool == .browserFrame
            || model.selectedTool == .dottedFrame
    }

    private var frameToolIcon: String {
        switch model.selectedTool {
        case .mobileFrame: "iphone"
        case .browserFrame: "macwindow"
        case .dottedFrame: "rectangle.dashed"
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
            x: min(max(anchor.x, fieldWidth / 2 + 54), size.width - fieldWidth / 2 - 12),
            y: min(max(anchor.y, 151), size.height - 86)
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

    private func performExport(_ action: WireframeExportAction) {
        model.finishPendingName()
        let feedback = exporter.perform(
            action, elements: model.elements,
            revision: model.contentRevision, colorScheme: colorScheme
        )
        let label: String
        switch action {
        case .save: label = "Saved"
        case .copyLink: label = "Link copied"
        case .appendLink: label = "Link appended"
        }
        showFeedback(feedback, label: label)
    }

    private func saveOrOpen() {
        model.finishPendingName()
        guard currentVersionIsSaved else {
            performExport(.save)
            return
        }
        isOpeningPreview = true
        Task { @MainActor in
            let feedback = await exporter.openInPreview(
                revision: model.contentRevision, colorScheme: colorScheme
            )
            isOpeningPreview = false
            showFeedback(feedback, label: "Opened in Preview")
        }
    }

    private func escape() {
        if model.handleEscape() {
            showFeedback(
                WireframeExportFeedback(message: "Action cancelled", isError: false),
                label: "Cancelled"
            )
        } else {
            onClose()
        }
    }

    private func showFeedback(_ feedback: WireframeExportFeedback, label: String) {
        feedbackTask?.cancel()
        exportFeedback = feedback
        // Retrigger confirmation even when the same action is repeated.
        feedbackLabel = nil
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(70))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.34, dampingFraction: 0.78)) {
                feedbackLabel = feedback.isError ? "Couldn’t complete" : label
            }
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                feedbackLabel = nil
                exportFeedback = nil
            }
        }
    }
}

private struct WireframeControlAnchors: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

private extension View {
    func wireframeControlBounds() -> some View {
        anchorPreference(key: WireframeControlAnchors.self, value: .bounds) { [$0] }
    }
}

struct WireframeArtworkView: View {
    let elements: [WireframeElement]
    let selectedTool: WireframeTool
    let draftPoints: [CGPoint]
    let namingElementID: UUID?
    let hoverPoint: CGPoint?
    let showsDraft: Bool
    var drawingColor: WireframeColor = .ink

    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        Canvas { context, size in
            drawGrid(in: &context, size: size)

            // Screenshots are always behind vector artwork, regardless of
            // insertion order; the array order still drives Undo.
            for element in elements {
                if let image = element.image {
                    context.draw(Image(nsImage: image), in: element.geometry.bounds)
                }
            }

            for element in elements {
                let isBeingNamed = element.id == namingElementID
                if element.image == nil || isBeingNamed {
                    context.stroke(
                        path(for: element.geometry),
                        with: .color(element.color.color(in: colorScheme)),
                        style: strokeStyle(for: element.geometry, isBeingNamed: isBeingNamed)
                    )
                }

                if !element.name.isEmpty, !isBeingNamed {
                    if let bounds = element.labelBounds,
                       elements.contains(where: { $0.image != nil && $0.geometry.bounds.intersects(bounds) }) {
                        // A screenshot may be any color, independent of Tiro's
                        // theme. Keep annotations readable over its pixels.
                        context.fill(
                            Path(roundedRect: bounds, cornerRadius: 4),
                            with: .color(palette.surface.opacity(0.94))
                        )
                    }
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
                with: .color(drawingColor.color(in: colorScheme)),
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

        case .dottedFrame:
            drawPreview(
                WireframeGeometryFactory.dottedFrame(from: first, to: previewPoint),
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
            with: .color(drawingColor.color(in: colorScheme)),
            style: style
        )
    }

    private func path(for geometry: WireframeGeometry) -> Path {
        switch geometry {
        case let .rectangle(rect), let .screenshot(rect):
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

        case let .dottedFrame(rect):
            return Path(
                roundedRect: rect,
                cornerRadius: min(10, min(rect.width, rect.height) * 0.08)
            )
        }
    }

    private func strokeStyle(
        for geometry: WireframeGeometry,
        isBeingNamed: Bool
    ) -> StrokeStyle {
        let isDottedFrame: Bool
        if case .dottedFrame = geometry {
            isDottedFrame = true
        } else {
            isDottedFrame = false
        }
        return StrokeStyle(
            lineWidth: isBeingNamed ? 2.25 : 1.65,
            lineCap: .round,
            lineJoin: .round,
            dash: isDottedFrame ? [1, 6] : []
        )
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
