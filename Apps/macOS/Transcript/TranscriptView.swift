import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptView: View {
    let translator: LiveTranslator
    @State private var selection: UUID?
    @State private var query = ""

    private var history: TranscriptHistory {
        translator.history
    }

    private var needle: String {
        TranscriptSearch.needle(query)
    }

    private var filteredSaved: [Transcript] {
        translator.savedTranscripts.filter { $0.matches(query) }
    }

    private var liveMatches: Bool {
        translator.isActive && translator.transcript.matches(query)
    }

    private var nothingMatches: Bool {
        !needle.isEmpty && !liveMatches && filteredSaved.isEmpty
    }

    private var shown: Transcript? {
        selection == translator.transcript.id && !translator.transcript.isEmpty ? translator.transcript
            : history.transcripts.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if liveMatches {
                    Section("Now") { row(translator.transcript) }
                }
                if !filteredSaved.isEmpty {
                    Section("Earlier") {
                        ForEach(filteredSaved) { transcript in
                            row(transcript).contextMenu {
                                Button("Delete", role: .destructive) { history.delete(transcript) }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: Text("Search transcripts"))
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if nothingMatches {
                ContentUnavailableView("No Matches", systemImage: "magnifyingglass",
                                       description: Text("No transcript has those words."))
            } else if let shown {
                TranscriptList(lines: shown.lines, originalFont: .callout, translationFont: .title3, query: query)
                    .id(shown.id) // A fresh scroll position per transcript; a long one's offset left a short one blank.
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
        .onChange(of: query) { old, new in
            guard TranscriptSearch.needle(old) != TranscriptSearch.needle(new) else { return }
            reconcileSelection()
        }
    }

    /// Keeps the open session when it still matches. Otherwise the first remaining row, or nothing.
    private func reconcileSelection() {
        if needle.isEmpty {
            if let selection, selectionExists(selection) { return }
            selection = translator.transcript.isEmpty ? history.transcripts.first?.id : translator.transcript.id
            return
        }
        if let selection, selectionMatches(selection) { return }
        if liveMatches {
            selection = translator.transcript.id
        } else {
            selection = filteredSaved.first?.id
        }
    }

    private func selectionExists(_ id: UUID) -> Bool {
        (translator.isActive && translator.transcript.id == id) || history.transcripts.contains { $0.id == id }
    }

    private func selectionMatches(_ id: UUID) -> Bool {
        (liveMatches && translator.transcript.id == id) || filteredSaved.contains { $0.id == id }
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
