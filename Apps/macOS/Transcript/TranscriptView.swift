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

    private var shown: Transcript? {
        selection == translator.transcript.id && !translator.transcript.isEmpty ? translator.transcript
            : history.transcripts.first { $0.id == selection }
    }

    var body: some View {
        let matches = translator.transcripts(matching: query)
        NavigationSplitView {
            List(selection: $selection) {
                if let live = matches.live {
                    Section("Now") { row(live) }
                }
                if !matches.saved.isEmpty {
                    Section("Earlier") {
                        ForEach(matches.saved) { transcript in
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
            if matches.nothingMatches {
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
        // Rows come and go with the search, the session in progress and deletes, not only when the query changes.
        .onChange(of: matches.ids) {
            // Without a search, a finished session that wasn't saved stays open although it has no row.
            if matches.isSearching || selection != translator.transcript.id || translator.transcript.isEmpty {
                selection = matches.selection(keeping: selection)
            }
        }
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
