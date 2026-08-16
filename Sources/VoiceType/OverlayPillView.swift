import SwiftUI

struct OverlayPillView: View {
    @ObservedObject var model: OverlayModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        HStack(spacing: 11) {
            TiroBrandMark(size: 34, showsShadow: false)
                .frame(width: 40, height: 40)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(palette.surface)
                        Image(systemName: iconName)
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(coreColor)
                    }
                    .frame(width: 17, height: 17)
                    .overlay {
                        Circle()
                            .strokeBorder(palette.ink.opacity(0.15), lineWidth: 0.75)
                    }
                    .padding(1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if case let .listening(level, _, screenshotCount) = model.state {
                    HStack(spacing: 7) {
                        SignalRail(
                            level: level,
                            color: palette.coral,
                            barWidth: screenshotCount > 0 ? 5 : 8
                        )
                            .frame(
                                width: screenshotCount > 0 ? 61 : 94,
                                height: 10
                            )
                        if screenshotCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "camera.fill")
                                Text("\(screenshotCount)")
                            }
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.aqua)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(palette.aqua.opacity(0.13), in: Capsule())
                        }
                    }
                } else {
                    Text(detail)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: 190, height: 58)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(palette.surface.opacity(colorScheme == .dark ? 0.68 : 0.58))
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(palette.ink.opacity(0.16), lineWidth: 0.75)
        }
        .padding(1)
    }

    private var title: String {
        switch model.state {
        case .preparing: "Warming up"
        case let .listening(_, locked, _): locked ? "Hands-free" : "Listening"
        case .transcribing: "Transcribing"
        case let .success(message): message
        case let .error(message): message
        case let .screenshotSuccess(message): message
        case let .screenshotError(message): message
        }
    }

    private var detail: String {
        switch model.state {
        case .preparing: "MIC CHECK"
        case .transcribing: "WHISPER ·••"
        case .success: "VOICE CLIPBOARD"
        case .error: "CHECK SETTINGS"
        case .screenshotSuccess: "TIRO SCREENSHOTS"
        case .screenshotError: "SCREENSHOT"
        case .listening: ""
        }
    }

    private var iconName: String {
        switch model.state {
        case .preparing: "mic.badge.plus"
        case let .listening(_, locked, _): locked ? "lock.fill" : "mic.fill"
        case .transcribing: "waveform"
        case .success: "checkmark"
        case .error: "exclamationmark"
        case .screenshotSuccess: "camera.fill"
        case .screenshotError: "camera.badge.ellipsis"
        }
    }

    private var coreColor: Color {
        switch model.state {
        case .preparing, .transcribing: palette.aqua
        case .listening: palette.coral
        case .success: palette.aqua
        case .error: palette.danger
        case .screenshotSuccess: palette.aqua
        case .screenshotError: palette.danger
        }
    }
}

private struct SignalRail: View {
    let level: Float
    let color: Color
    let barWidth: CGFloat

    private let weights: [CGFloat] = [0.38, 0.72, 1, 0.62, 0.84, 0.48, 0.7, 0.32]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(color.opacity(0.78))
                    .frame(
                        width: barWidth,
                        height: max(2.5, 10 * weight * CGFloat(0.28 + level * 0.9))
                    )
            }
        }
        .animation(.linear(duration: 0.07), value: level)
    }
}
