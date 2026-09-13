import SwiftUI

@MainActor
final class WireframePresentation: ObservableObject {
    enum Phase {
        case hidden, dot, pill, board, burst
    }

    @Published var phase: Phase = .hidden
    @Published var burstProgress: CGFloat = 0
    @Published var reducesMotion = false
}

// Keep the actual window and canvas at their final size. Only the visual shell
// morphs, so drawing coordinates and toolbar layout stay stable throughout.
struct WireframePresentationView<Content: View>: View {
    @ObservedObject var presentation: WireframePresentation
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let expanded = presentation.phase == .board || presentation.reducesMotion
            let isPill = presentation.phase == .pill
            let width = expanded ? size.width - 20 : (isPill ? 170.0 : 8.0)
            let height = expanded ? size.height - 20 : (isPill ? 38.0 : 8.0)
            let center = CGPoint(
                x: expanded ? size.width / 2 : size.width - 95,
                y: size.height / 2
            )
            let radius = expanded ? 24.0 : height / 2
            let palette = VoiceTypePalette(colorScheme)
            let visible = presentation.phase != .hidden && presentation.phase != .burst

            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(presentation.phase == .dot ? palette.aqua : palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(palette.ink.opacity(0.16), lineWidth: 0.75)
                    }
                    .frame(width: width, height: height)
                    .shadow(color: .black.opacity(0.12), radius: 7, y: 3)
                    .position(center)
                    .opacity(visible ? 1 : 0)

                content
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(
                        x: width / max(1, size.width - 20),
                        y: height / max(1, size.height - 20)
                    )
                    .position(center)
                    .opacity(presentation.phase == .board ? 1 : 0)
                    .mask {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .frame(width: width, height: height)
                            .position(center)
                    }
                    .allowsHitTesting(presentation.phase == .board)
                    .accessibilityHidden(presentation.phase != .board)

                Label("Wireframe", systemImage: "square.grid.3x3")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.75))
                    .position(center)
                    .opacity(isPill ? 1 : 0)
                    .accessibilityHidden(true)

                if !presentation.reducesMotion {
                    ForEach(0..<6) { index in
                        let angle = Double(index) * .pi / 3 + .pi / 12
                        let distance = 4 + presentation.burstProgress * 18
                        Circle()
                            .fill(palette.aqua)
                            .frame(width: 1.8, height: 1.8)
                            .scaleEffect(1 - presentation.burstProgress * 0.7)
                            .position(
                                x: size.width - 95 + cos(angle) * distance,
                                y: size.height / 2 + sin(angle) * distance
                            )
                            .opacity(
                                presentation.phase == .burst
                                    ? 0.38 * (1 - presentation.burstProgress) : 0
                            )
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }
}
