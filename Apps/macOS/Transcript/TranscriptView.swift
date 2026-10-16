import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// Transcripts window: the session in progress and saved sessions in the sidebar; export, copy or delete the one shown.
struct TranscriptView: View {
    let translator: LiveTranslator
    @State private var selection: UUID?

    private var history: TranscriptHistory {
        translator.history
    }

    private var saved: [Transcript] {
        history.transcripts.filter { !translator.isActive || $0.id != translator.transcript.id } // In progress is "Now".
    }

    private var shown: Transcript? {
        selection == translator.transcript.id && !translator.transcript.isEmpty ? translator.transcript
            : history.transcripts.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if translator.isActive {
                    Section("Now") { row(translator.transcript) }
                }
                Section("Earlier") {
                    ForEach(saved) { transcript in
                        row(transcript).contextMenu {
                            Button("Delete", role: .destructive) { history.delete(transcript) }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let shown {
                TranscriptList(lines: shown.lines, originalFont: .callout, translationFont: .title3)
                    .padding(20)
                    .navigationTitle(shown.title)
                    .navigationSubtitle(shown.summary)
                    .toolbar { toolbar(for: shown) }
            } else {
                ContentUnavailableView("No Transcript", systemImage: "text.bubble",
                                       description: Text(translator.savesTranscripts ? "Each listening session is kept here, on this Mac."
                                           : "Saving transcripts is off in Settings."))
            }
        }
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .frame(minWidth: 620, minHeight: 360)
        .onAppear { selection = selection ?? (translator.transcript.isEmpty ? history.transcripts.first?.id : translator.transcript.id) }
    }

    private func row(_ transcript: Transcript) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transcript.title).font(.headline)
            Text(transcript.summary).font(.caption).foregroundStyle(Color.hvMuted)
        }
        .tag(transcript.id)
    }

    @ToolbarContentBuilder
    private func toolbar(for transcript: Transcript) -> some ToolbarContent {
        ToolbarItemGroup {
            ShareLink(item: transcript, preview: SharePreview(transcript.title)) { Label("Export", systemImage: "square.and.arrow.up") }
            Button("Copy", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(transcript.text, forType: .string)
            }
            if history.transcripts.contains(where: { $0.id == transcript.id }), !(translator.isActive && transcript.id == translator.transcript.id) {
                Button("Delete", systemImage: "trash") { history.delete(transcript) }
            }
        }
    }
}
