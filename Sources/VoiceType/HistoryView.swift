import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: TranscriptHistoryStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var confirmingClear = false
    @State private var copiedEntryID: UUID?

    private var palette: VoiceTypePalette { VoiceTypePalette(colorScheme) }

    private var filteredEntries: [TranscriptHistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.entries }
        return store.entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.entries.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 22)
        }
        .alert("Clear transcript history?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear all", role: .destructive) { store.clear() }
        } message: {
            Text("This permanently removes every saved transcript.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("VOICE TAPE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(palette.coral)
                    Text("Transcript history")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(palette.ink)
                }
                Spacer()
                if !store.entries.isEmpty {
                    Button("Clear all") { confirmingClear = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.coral)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.ink.opacity(0.50))
                TextField("Search what you said", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .rounded))
                Text("\(store.entries.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink.opacity(0.50))
            }
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 11) {
                if filteredEntries.isEmpty {
                    Text("No transcripts match that search.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(palette.ink.opacity(0.58))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 54)
                } else {
                    ForEach(filteredEntries) { entry in
                        HistoryRow(
                            entry: entry,
                            palette: palette,
                            isCopied: copiedEntryID == entry.id,
                            onCopy: { copy(entry) },
                            onDelete: { store.delete(entry) }
                        )
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(palette.coral)
                .frame(width: 58, height: 58)
                .background(palette.aqua.opacity(0.23), in: Circle())
            Text("Your next transcript starts the tape.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ink)
            Text("Use ⌃⌘V in any active text field to paste the latest one again.")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(palette.ink.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy(_ entry: TranscriptHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        copiedEntryID = entry.id
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copiedEntryID == entry.id {
                copiedEntryID = nil
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: TranscriptHistoryEntry
    let palette: VoiceTypePalette
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 6) {
                Circle()
                    .fill(palette.coral)
                    .frame(width: 8, height: 8)
                Capsule()
                    .fill(palette.aqua.opacity(0.45))
                    .frame(width: 2, height: 34)
            }
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink.opacity(0.50))
                    Spacer()
                    Button(isCopied ? "Copied" : "Copy", action: onCopy)
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isCopied ? palette.aqua : palette.ink.opacity(0.74))
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(palette.coral.opacity(0.82))
                    .help("Delete transcript")
                }

                Text(entry.text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(palette.ink.opacity(0.90))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(palette.stroke, lineWidth: 1)
            }
        }
    }
}
