import SwiftUI

struct OverlayPillView: View {
    @ObservedObject var model: OverlayModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(coreColor.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(coreColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if case let .listening(level, _) = model.state {
                    SignalRail(level: level, color: palette.coral)
                        .frame(width: 94, height: 10)
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
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(palette.ink.opacity(0.16), lineWidth: 0.75)
        }
        .padding(1)
    }

    private var title: String {
        switch model.state {
        case .preparing: "Warming up"
        case let .listening(_, locked): locked ? "Hands-free" : "Listening"
        case .transcribing: "Transcribing"
        case let .success(message): message
        case let .error(message): message
        }
    }

    private var detail: String {
        switch model.state {
        case .preparing: "MIC CHECK"
        case .transcribing: "WHISPER ·••"
        case .success: "VOICE CLIPBOARD"
        case .error: "CHECK SETTINGS"
        case .listening: ""
        }
    }

    private var iconName: String {
        switch model.state {
        case .preparing: "mic.badge.plus"
        case let .listening(_, locked): locked ? "lock.fill" : "mic.fill"
        case .transcribing: "waveform"
        case .success: "checkmark"
        case .error: "exclamationmark"
        }
    }

    private var coreColor: Color {
        switch model.state {
        case .preparing, .transcribing: palette.aqua
        case .listening: palette.coral
        case .success: palette.aqua
        case .error: palette.coral
        }
    }
}

private struct SignalRail: View {
    let level: Float
    let color: Color

    private let weights: [CGFloat] = [0.38, 0.72, 1, 0.62, 0.84, 0.48, 0.7, 0.32]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(weights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(color.opacity(0.78))
                    .frame(
                        width: 8,
                        height: max(2.5, 10 * weight * CGFloat(0.28 + level * 0.9))
                    )
            }
        }
        .animation(.linear(duration: 0.07), value: level)
    }
}
