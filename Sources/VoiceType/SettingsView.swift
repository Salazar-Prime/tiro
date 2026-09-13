import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case screenshots
    case transcription
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .screenshots: "Screenshots"
        case .transcription: "Transcription"
        case .history: "History"
        }
    }

    var heading: String {
        switch self {
        case .general: "App setup"
        case .shortcuts: "Keyboard shortcuts"
        case .screenshots: "Screenshot capture"
        case .transcription: "Speech to text"
        case .history: "Transcript history"
        }
    }

    var explanation: String {
        switch self {
        case .general:
            "Check system access and review the gestures you’ll use most."
        case .shortcuts:
            "Choose how you start dictation, open tools, paste history, and trigger captures."
        case .screenshots:
            "Capture the visible screen or a selection, then insert it where you’re working."
        case .transcription:
            "Choose cloud or on-device transcription and tune how speech becomes text."
        case .history:
            "Search, copy, or remove the words and screenshot paths you’ve captured."
        }
    }

    var icon: String {
        switch self {
        case .general: "switch.2"
        case .shortcuts: "command"
        case .screenshots: "viewfinder"
        case .transcription: "waveform"
        case .history: "clock.arrow.circlepath"
        }
    }

    func tint(_ palette: VoiceTypePalette) -> Color {
        switch self {
        case .general, .screenshots, .history: palette.aqua
        case .shortcuts, .transcription: palette.coral
        }
    }
}

@MainActor
final class SettingsNavigationModel: ObservableObject {
    @Published var selectedPage: SettingsPage = .general
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var historyStore: TranscriptHistoryStore
    @ObservedObject var navigation: SettingsNavigationModel
    @StateObject private var shortcutRecorder = ShortcutRecordingSession()
    @Environment(\.colorScheme) private var colorScheme

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }
    private var selectedPage: SettingsPage { navigation.selectedPage }

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                settingsNavigation

                Divider()
                    .overlay(palette.stroke)

                if selectedPage == .history {
                    HistoryView(
                        store: historyStore,
                        pasteShortcut: model.shortcutConfiguration.pasteLast
                    )
                    .id(selectedPage)
                    .clipped()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            pageHeading
                            selectedPageContent
                        }
                        .id(selectedPage)
                        .padding(.horizontal, 30)
                        .padding(.top, 25)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onAppear { model.refreshPermissions() }
        .onChange(of: selectedPage) {
            shortcutRecorder.cancel()
        }
        .onDisappear { shortcutRecorder.cancel() }
    }

    @ViewBuilder
    private var selectedPageContent: some View {
        switch selectedPage {
        case .general:
            shortcutStrip
            setupSection
        case .shortcuts:
            ShortcutSettingsSection(
                model: model,
                recorder: shortcutRecorder,
                palette: palette
            )
        case .screenshots:
            screenshotSection
        case .transcription:
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
        case .history:
            EmptyView()
        }
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
        HStack(spacing: 13) {
            TiroBrandMark(size: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tiro")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(palette.ink)
                Text("SETTINGS · \(selectedPage.title.uppercased())")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(palette.ink.opacity(0.48))
            }

            Spacer()

            Button(action: model.previewOverlay) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(palette.aqua)
                        .frame(width: 7, height: 7)
                    Text("Preview pill")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(palette.aqua.opacity(colorScheme == .dark ? 0.16 : 0.30), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Preview the signal capsule")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .background {
            LinearGradient(
                colors: [
                    palette.aqua.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    Color.clear,
                    palette.coral.opacity(colorScheme == .dark ? 0.07 : 0.04)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var settingsNavigation: some View {
        HStack(spacing: 4) {
            ForEach(SettingsPage.allCases) { page in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        navigation.selectedPage = page
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: page.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(page.title)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(
                        selectedPage == page
                            ? palette.ink
                            : palette.ink.opacity(0.52)
                    )
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                    .background(
                        selectedPage == page ? palette.field : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(page.tint(palette))
                            .frame(width: selectedPage == page ? 24 : 5, height: 3)
                            .opacity(selectedPage == page ? 1 : 0.26)
                            .padding(.bottom, 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(palette.stroke, lineWidth: 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var pageHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(selectedPage.heading)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-0.55)
                .foregroundStyle(palette.ink)
            Text(selectedPage.explanation)
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcutStrip: some View {
        HStack(spacing: 0) {
            ShortcutCell(
                keys: model.shortcutConfiguration.voiceTyping.displayTokens,
                label: "Hold to speak",
                palette: palette
            )
            Divider().frame(height: 48)
            ShortcutCell(
                keys: ["2×"] + model.shortcutConfiguration.voiceTyping.displayTokens,
                label: "Lock the mic",
                palette: palette
            )
            Divider().frame(height: 48)
            ShortcutCell(
                keys: model.shortcutConfiguration.pasteLast?.displayTokens ?? ["—"],
                label: "Paste last",
                palette: palette
            )
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
            PermissionRow(
                icon: "rectangle.dashed.badge.record",
                title: "Screen Recording",
                explanation: "Capture only when you choose",
                status: model.screenCaptureStatus,
                tint: palette.coral,
                palette: palette,
                action: model.requestScreenCapture
            )
        }
    }

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(text: "SCREENSHOT DROP", palette: palette)
                Spacer()
                Text("\(model.shortcutConfiguration.captureSelection?.displayName ?? "NO SHORTCUT") · SELECTION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.52))
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ScreenshotAction(
                        icon: "rectangle.inset.filled",
                        title: "Visible screen",
                        detail: "Without menu bar or Dock",
                        tint: palette.aqua,
                        palette: palette,
                        action: model.captureUsableScreen
                    )
                    ScreenshotAction(
                        icon: "viewfinder",
                        title: "Selection",
                        detail: "Drag to frame any area",
                        tint: palette.coral,
                        palette: palette,
                        action: model.captureSelection
                    )
                }
                .padding(10)

                Divider()
                    .padding(.horizontal, 12)

                HStack(spacing: 9) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(palette.aqua)
                    Text("Pictures / Tiro screenshots")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.ink.opacity(0.62))
                    Spacer()
                    Button("Open folder", action: model.openScreenshotsFolder)
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.ink)
                }
                .padding(.horizontal, 15)
                .frame(height: 42)
            }
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
            .disabled(model.screenshotCaptureIsBusy)
            .opacity(model.screenshotCaptureIsBusy ? 0.62 : 1)

            screenshotPathWrapperCard

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    attachmentShortcutHelp,
                    systemImage: "camera.badge.clock"
                )
                    .foregroundStyle(palette.aqua)
                Text("Standalone captures are added to history as readable local paths. Compatible fields receive the image; other fields receive the path \(screenshotPasteHelp).")
                    .foregroundStyle(palette.ink.opacity(0.60))
            }
            .font(.system(size: 10.5, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var screenshotPathWrapperCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: "text.quote")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.aqua)
                    .frame(width: 34, height: 34)
                    .background(palette.aqua.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Surround pasted paths")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.ink)
                    Text("Add text before and after every screenshot path")
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(palette.ink.opacity(0.56))
                }

                Spacer()

                Toggle("", isOn: $model.screenshotPathWrappingEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Turn screenshot path wrapping on or off")
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                pathAffixField(
                    label: "BEFORE PATH",
                    placeholder: "Blank",
                    text: $model.screenshotPathPrefix
                )
                pathAffixField(
                    label: "AFTER PATH",
                    placeholder: "Blank",
                    text: $model.screenshotPathSuffix
                )
            }
            .disabled(!model.screenshotPathWrappingEnabled)
            .opacity(model.screenshotPathWrappingEnabled ? 1 : 0.44)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("PREVIEW")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(palette.ink.opacity(0.46))
                    Spacer()
                    Button("Reset to quotes", action: model.resetScreenshotPathWrapper)
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.coral)
                }

                Text(screenshotPathPreview)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.76))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 11)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .background(palette.field, in: RoundedRectangle(cornerRadius: 9))
            }

            Text("Leave either field blank if you only need text on one side. Turn this off for a plain path.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.54))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(palette.stroke, lineWidth: 1)
        }
    }

    private func pathAffixField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.65)
                .foregroundStyle(palette.ink.opacity(0.46))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, design: .monospaced))
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(palette.field, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var screenshotPathPreview: String {
        model.screenshotPathWrapper.format(
            "/Users/you/Pictures/Tiro screenshots/Example.png"
        )
    }

    private var attachmentShortcutHelp: String {
        guard let shortcut = model.shortcutConfiguration.attachScreenshot else {
            return "Set an attachment shortcut above to add screenshots while speaking."
        }
        return "While voice typing, use \(shortcut.displayName) to attach a screenshot."
    }

    private var screenshotPasteHelp: String {
        guard let shortcut = model.shortcutConfiguration.pasteLast else {
            return "from transcript history"
        }
        return "with \(shortcut.displayName)"
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
                    .foregroundStyle(model.hasAPIKey ? palette.aqua : palette.danger)
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
                    .foregroundStyle(palette.danger)
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

private struct ScreenshotAction: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let palette: VoiceTypePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(tint.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.ink)
                    Text(detail)
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(palette.ink.opacity(0.56))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(palette.field.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
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
                        .foregroundStyle(palette.danger)
                    }
                }
                .font(.system(size: 10.5, weight: .medium))

                if case let .failed(message) = manager.state {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.danger)
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
