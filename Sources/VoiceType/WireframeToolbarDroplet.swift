import SwiftUI

private struct WireframeToolbarAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func wireframeToolbarAnchor(_ id: String) -> some View {
        anchorPreference(key: WireframeToolbarAnchors.self, value: .bounds) { [id: $0] }
    }
}

/// The button highlight, liquid neck, and label share one glass surface, drawn
/// behind the controls. The toolbar is cut away beneath it to avoid a seam.
struct WireframeToolbarDroplet: ViewModifier {
    let selectedID: String
    let label: String?
    let palette: VoiceTypePalette
    let reduceMotion: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(5)
            .fixedSize()
            .backgroundPreferenceValue(WireframeToolbarAnchors.self) { anchors in
                GeometryReader { proxy in
                    let button = anchors[selectedID].map { proxy[$0] }
                    let glass = WireframeGlassShape(
                        buttonX: button?.midX ?? 19,
                        buttonTop: button?.minY ?? 5,
                        toolbarHeight: proxy.size.height
                    )
                    let hasDroplet = label != nil && button != nil
                    ZStack(alignment: .topLeading) {
                        toolbarSurface
                            .frame(height: proxy.size.height)
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .topLeading) {
                                        if hasDroplet {
                                            glass.fill(.black)
                                                .frame(height: proxy.size.height + 38)
                                                .blendMode(.destinationOut)
                                        }
                                    }
                                    .compositingGroup()
                            }

                        if let label, let button {
                            glass.fill(.ultraThinMaterial)
                                .overlay {
                                    glass.fill(LinearGradient(
                                        colors: [palette.aqua.opacity(0.23), palette.aqua.opacity(0.10), palette.aqua.opacity(0.18)],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                                }
                                .overlay {
                                    glass.stroke(LinearGradient(
                                        colors: [.white.opacity(colorScheme == .dark ? 0.27 : 0.65), palette.aqua.opacity(0.25)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 0.65)
                                }
                                .overlay(alignment: .topLeading) {
                                    let pill = glass.labelBounds(in: CGRect(
                                        origin: .zero,
                                        size: CGSize(width: proxy.size.width, height: proxy.size.height + 38)
                                    ))
                                    Text(label)
                                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(palette.ink.opacity(0.86))
                                        .lineLimit(1)
                                        .frame(width: pill.width - 16, height: pill.height)
                                        .position(x: pill.midX, y: pill.midY)
                                }
                                .frame(height: proxy.size.height + 38)
                                .transition(reduceMotion ? .opacity : .asymmetric(
                                    insertion: .scale(scale: 0.05, anchor: UnitPoint(
                                        x: button.midX / proxy.size.width,
                                        y: button.minY / (proxy.size.height + 38)
                                    )).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82),
                    value: selectedID
                )
            }
            .padding(.bottom, 38)
    }

    private var toolbarSurface: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            // Keep the backdrop outside the cutout: nesting another material
            // here can leave its rectangular edge visible through the neck.
            .fill(palette.surface.opacity(colorScheme == .dark ? 0.88 : 0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(palette.ink.opacity(0.14), lineWidth: 0.75)
            }
    }
}

/// One closed contour, with no horizontal edge between the highlight and pill.
struct WireframeGlassShape: Shape {
    var buttonX: CGFloat
    var buttonTop: CGFloat
    var toolbarHeight: CGFloat

    var animatableData: CGFloat {
        get { buttonX }
        set { buttonX = newValue }
    }

    func labelBounds(in rect: CGRect) -> CGRect {
        let width = min(CGFloat(150), rect.width)
        let center = min(max(buttonX, width / 2), rect.width - width / 2)
        return CGRect(x: center - width / 2, y: toolbarHeight + 9, width: width, height: 26)
    }

    func path(in rect: CGRect) -> Path {
        let x = buttonX
        let top = buttonTop
        let bottom = top + 28
        let pill = labelBounds(in: rect)
        let neckY = (bottom + pill.minY) / 2
        let joinLeft = max(pill.minX + 13, x - 18)
        let joinRight = min(pill.maxX - 13, x + 18)
        var path = Path()

        path.move(to: CGPoint(x: x - 7, y: top))
        path.addLine(to: CGPoint(x: x + 7, y: top))
        path.addQuadCurve(to: CGPoint(x: x + 14, y: top + 7), control: CGPoint(x: x + 14, y: top))
        path.addLine(to: CGPoint(x: x + 14, y: bottom - 7))
        path.addCurve(to: CGPoint(x: x + 5, y: neckY),
                      control1: CGPoint(x: x + 14, y: bottom + 1),
                      control2: CGPoint(x: x + 5, y: bottom + 1))
        path.addCurve(to: CGPoint(x: joinRight, y: pill.minY),
                      control1: CGPoint(x: x + 5, y: pill.minY),
                      control2: CGPoint(x: max(joinRight - 8, x + 5), y: pill.minY))

        path.addLine(to: CGPoint(x: pill.maxX - 13, y: pill.minY))
        path.addCurve(to: CGPoint(x: pill.maxX, y: pill.midY),
                      control1: CGPoint(x: pill.maxX - 5.82, y: pill.minY),
                      control2: CGPoint(x: pill.maxX, y: pill.midY - 7.18))
        path.addCurve(to: CGPoint(x: pill.maxX - 13, y: pill.maxY),
                      control1: CGPoint(x: pill.maxX, y: pill.midY + 7.18),
                      control2: CGPoint(x: pill.maxX - 5.82, y: pill.maxY))
        path.addLine(to: CGPoint(x: pill.minX + 13, y: pill.maxY))
        path.addCurve(to: CGPoint(x: pill.minX, y: pill.midY),
                      control1: CGPoint(x: pill.minX + 5.82, y: pill.maxY),
                      control2: CGPoint(x: pill.minX, y: pill.midY + 7.18))
        path.addCurve(to: CGPoint(x: pill.minX + 13, y: pill.minY),
                      control1: CGPoint(x: pill.minX, y: pill.midY - 7.18),
                      control2: CGPoint(x: pill.minX + 5.82, y: pill.minY))

        path.addLine(to: CGPoint(x: joinLeft, y: pill.minY))
        path.addCurve(to: CGPoint(x: x - 5, y: neckY),
                      control1: CGPoint(x: min(joinLeft + 8, x - 5), y: pill.minY),
                      control2: CGPoint(x: x - 5, y: pill.minY))
        path.addCurve(to: CGPoint(x: x - 14, y: bottom - 7),
                      control1: CGPoint(x: x - 5, y: bottom + 1),
                      control2: CGPoint(x: x - 14, y: bottom + 1))
        path.addLine(to: CGPoint(x: x - 14, y: top + 7))
        path.addQuadCurve(to: CGPoint(x: x - 7, y: top), control: CGPoint(x: x - 14, y: top))
        path.closeSubpath()
        return path
    }
}
