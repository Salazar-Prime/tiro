import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    shortcutStrip
                    setupSection
                    engineSection
                    if model.transcriptionEngine == .cloud {
                        apiKeySection
                    } else {
                        OfflineModelSection(
                            manager: model.offlineModel,
                            palette: palette
                        )
                    }
                    transcriptionSection
                    privacyNote
                }
                .padding(.horizontal, 30)
                .padding(.top, 34)
                .padding(.bottom, 28)
            }
        }
        .onAppear { model.refreshPermissions() }
    }

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "TRANSCRIPTION ENGINE", palette: palette)
                Spacer()
                Text("ENGLISH")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.52))
            }

            HStack(spacing: 8) {
                ForEach(TranscriptionEngine.allCases) { engine in
                    EngineChoice(
                        engine: engine,
                        isSelected: model.transcriptionEngine == engine,
                        palette: palette
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            model.transcriptionEngine = engine
                        }
                    }
                }
            }
            .padding(6)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TIRO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(palette.coral)
                Text("Speak. Release.\nIt’s there.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(palette.ink)
            }
            Spacer()
            Button(action: model.previewOverlay) {
                VStack(spacing: 7) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 21, weight: .semibold))
                    Text("PREVIEW")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                }
                .foregroundStyle(palette.ink)
                .frame(width: 72, height: 72)
                .background(palette.aqua.opacity(colorScheme == .dark ? 0.19 : 0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Preview the signal capsule")
        }
    }

    private var shortcutStrip: some View {
        HStack(spacing: 0) {
            ShortcutCell(keys: ["⌃", "⌥"], label: "Hold to speak", palette: palette)
            Divider().frame(height: 48)
            ShortcutCell(keys: ["2×", "⌃", "⌥"], label: "Lock the mic", palette: palette)
            Divider().frame(height: 48)
            ShortcutCell(keys: ["⌃", "⌘", "V"], label: "Paste last", palette: palette)
        }
        .padding(.vertical, 12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(palette.stroke, lineWidth: 1)
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(text: "SYSTEM ACCESS", palette: palette)
            PermissionRow(
                icon: "mic.fill",
                title: "Microphone",
                explanation: "Hear your dictation",
                status: model.microphoneStatus,
                tint: palette.coral,
                palette: palette,
                action: model.requestMicrophone
            )
            PermissionRow(
                icon: "cursorarrow.motionlines",
                title: "Accessibility",
                explanation: "Watch shortcuts and insert text",
                status: model.accessibilityStatus,
                tint: palette.aqua,
                palette: palette,
                action: model.requestAccessibility
            )
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "OPENAI", palette: palette)
                Spacer()
                Text("GPT-4O MINI TRANSCRIBE · CLOUD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.52))
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    SecureField(
                        model.hasAPIKey ? "Replace saved API key" : "sk-…",
                        text: $model.keyEntry
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(palette.field, in: RoundedRectangle(cornerRadius: 10))

                    Button("Save") { model.saveAPIKey() }
                        .buttonStyle(SignalButtonStyle(color: palette.ink, foregroundColor: palette.canvas))
                }

                HStack {
                    Label(
                        model.hasAPIKey ? "Key saved in macOS Keychain" : "An API key is required",
                        systemImage: model.hasAPIKey ? "checkmark.seal.fill" : "key.fill"
                    )
                    .foregroundStyle(model.hasAPIKey ? palette.aqua : palette.coral)
                    Spacer()
                    Link(
                        "Create a key ↗",
                        destination: URL(string: "https://platform.openai.com/api-keys")!
                    )
                    .foregroundStyle(palette.ink.opacity(0.72))
                }
                .font(.system(size: 11, weight: .medium))

                if let keyMessage = model.keyMessage {
                    Text(keyMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink.opacity(0.66))
                }

                if model.hasAPIKey {
                    Button("Remove saved key", role: .destructive) {
                        model.removeAPIKey()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.coral)
                }
            }
            .padding(16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "TRANSCRIPTION", palette: palette)
                Spacer()
                Text(model.transcriptionEngine == .cloud ? "CLOUD PROMPT" : "INITIAL PROMPT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.52))
            }

            VStack(alignment: .leading, spacing: 11) {
                Text(
                    model.transcriptionEngine == .cloud
                        ? "Instructions"
                        : "Vocabulary and context (optional)"
                )
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))

                ZStack(alignment: .topLeading) {
                    TextEditor(text: selectedPrompt)
                        .font(.system(size: 12.5, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 98)
                        .background(palette.field, in: RoundedRectangle(cornerRadius: 10))
                    if model.transcriptionEngine == .offline,
                       model.offlineInitialPrompt.isEmpty {
                        Text("Names, acronyms, or domain-specific terms")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(palette.ink.opacity(0.38))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 17)
                            .allowsHitTesting(false)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(
                        model.transcriptionEngine == .cloud
                            ? "Saved automatically and used on the next recording."
                            : "Helps Whisper recognize terms. Offline mode does not rewrite or post-process text."
                    )
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.ink.opacity(0.60))
                    Spacer()
                    Button("Reset") {
                        model.resetPromptForSelectedEngine()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.coral)
                }
            }
            .padding(16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }

    private var selectedPrompt: Binding<String> {
        Binding(
            get: {
                model.transcriptionEngine == .cloud
                    ? model.transcriptionInstructions
                    : model.offlineInitialPrompt
            },
            set: { value in
                if model.transcriptionEngine == .cloud {
                    model.transcriptionInstructions = value
                } else {
                    model.offlineInitialPrompt = value
                }
            }
        )
    }

    private var privacyNote: some View {
        Text(
            model.transcriptionEngine == .offline
                ? "System output is muted only while Tiro records and restored when recording stops. Offline audio and transcription stay on this Mac. Temporary audio is deleted after transcription; transcript history remains until you delete it."
                : "System output is muted only while Tiro records and restored when recording stops. Audio is then sent to OpenAI and deleted after transcription. Transcript history is saved on this Mac and can be cleared from Tiro’s menu-bar history window."
        )
            .font(.system(size: 11.5, weight: .regular))
            .foregroundStyle(palette.ink.opacity(0.64))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct EngineChoice: View {
    let engine: TranscriptionEngine
    let isSelected: Bool
    let palette: VoiceTypePalette
    let action: () -> Void

    private var tint: Color {
        engine == .cloud ? palette.coral : palette.aqua
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: engine.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.ink)
                    Text(engine.detail.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(palette.ink.opacity(0.52))
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(isSelected ? tint : palette.stroke)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isSelected ? tint.opacity(0.11) : palette.field.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(isSelected ? tint.opacity(0.42) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OfflineModelSection: View {
    @ObservedObject var manager: OfflineModelManager
    let palette: VoiceTypePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "ON-DEVICE MODEL", palette: palette)
                Spacer()
                Text("WHISPER.CPP 1.9.2")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.52))
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.aqua)
                        .frame(width: 38, height: 38)
                        .background(palette.aqua.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(OfflineModelManager.modelName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("English · balanced accuracy · \(OfflineModelManager.downloadSize)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(palette.ink.opacity(0.60))
                    }
                    Spacer()
                    stateControl
                }

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    Label("Audio never leaves this Mac", systemImage: "lock.shield.fill")
                        .foregroundStyle(palette.aqua)
                    Spacer()
                    if manager.isReady {
                        Button("Remove model", role: .destructive) {
                            manager.removeModel()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.coral)
                    }
                }
                .font(.system(size: 10.5, weight: .medium))

                if case let .failed(message) = manager.state {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.coral)
                }
            }
            .padding(16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var stateControl: some View {
        switch manager.state {
        case .ready:
            Label("Ready", systemImage: "checkmark")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.aqua)
        case .downloading:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("DOWNLOADING")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.60))
            }
        case .missing, .failed:
            Button(manager.state == .missing ? "Download" : "Retry") {
                manager.download()
            }
            .buttonStyle(
                SignalButtonStyle(
                    color: palette.ink,
                    foregroundColor: palette.canvas
                )
            )
        }
    }
}

private struct ShortcutCell: View {
    let keys: [String]
    let label: String
    let palette: VoiceTypePalette

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(minWidth: 20, minHeight: 20)
                        .foregroundStyle(palette.ink)
                        .background(palette.field, in: RoundedRectangle(cornerRadius: 5))
                }
            }
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(palette.ink.opacity(0.64))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SectionLabel: View {
    let text: String
    let palette: VoiceTypePalette

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(palette.ink.opacity(0.54))
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let explanation: String
    let status: PermissionStatus
    let tint: Color
    let palette: VoiceTypePalette
    let action: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if status == .granted {
                Label("Ready", systemImage: "checkmark")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.aqua)
            } else {
                Button(status == .denied ? "Open settings" : "Grant") {
                    action()
                }
                .buttonStyle(SignalButtonStyle(color: palette.ink, foregroundColor: palette.canvas))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(palette.stroke, lineWidth: 1)
        }
    }
}

private struct SignalButtonStyle: ButtonStyle {
    let color: Color
    let foregroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
