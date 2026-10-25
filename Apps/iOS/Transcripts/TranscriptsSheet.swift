import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptsSheet: View {
    let translator: LiveTranslator

    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var selection: UUID?
    @State private var query = ""

    var body: some View {
        let matches = translator.transcripts(matching: query)
        if widthClass == .regular {
            split(matches)
        } else {
            stack(matches)
        }
    }

    private func stack(_ matches: TranscriptMatches) -> some View {
        NavigationStack {
            List {
                if let live = matches.live {
                    Section("Now") {
                        NavigationLink { LiveTranscriptDetail(translator: translator, query: query) } label: { TranscriptRow(transcript: live) }
                    }
                }
                if !matches.saved.isEmpty {
                    Section("Earlier") {
                        ForEach(matches.saved) { transcript in
                            NavigationLink {
                                TranscriptDetailView(transcript: transcript, delete: { translator.history.delete(transcript) }, query: query)
                            } label: {
                                TranscriptRow(transcript: transcript)
                            }
                        }
                        .onDelete { offsets in offsets.map { matches.saved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, emptyLibrary: !matches.isSearching && matches.isEmpty,
                                          noMatches: matches.nothingMatches))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search transcripts"))
        }
        .presentationDetents([.medium, .large])
    }

    /// Wide screens (the open iPhone Duo, iPad): the list beside the transcript, like the Mac window.
    private func split(_ matches: TranscriptMatches) -> some View {
        NavigationSplitView {
            List(selection: $selection) {
                if let live = matches.live {
                    Section("Now") { TranscriptRow(transcript: live).tag(live.id) }
                }
                if !matches.saved.isEmpty {
                    Section("Earlier") {
                        ForEach(matches.saved) { TranscriptRow(transcript: $0).tag($0.id) }
                            .onDelete { offsets in offsets.map { matches.saved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, emptyLibrary: !matches.isSearching && matches.isEmpty, noMatches: false))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search transcripts"))
        } detail: {
            if matches.nothingMatches {
                ContentUnavailableView("No Matches", systemImage: "magnifyingglass",
                                       description: Text("No transcript has those words."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.hvGround)
            } else if let live = matches.live, selection == live.id {
                LiveTranscriptDetail(translator: translator, query: query)
            } else if let transcript = matches.saved.first(where: { $0.id == selection }) {
                TranscriptDetailView(transcript: transcript, delete: { translator.history.delete(transcript) }, closesOnDelete: false,
                                     query: query)
                    .id(transcript.id)
            }
        }
        .onAppear { selection = matches.selection(keeping: selection) }
        // Rows come and go with the search, the session in progress and deletes, not only when the query changes.
        .onChange(of: matches.ids) { selection = matches.selection(keeping: selection) }
        .presentationSizing(.page)
    }
}

private struct TranscriptListStyle: ViewModifier {
    let translator: LiveTranslator
    let emptyLibrary: Bool
    let noMatches: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .overlay {
                if noMatches {
                    ContentUnavailableView("No Matches", systemImage: "magnifyingglass",
                                           description: Text("No transcript has those words."))
                } else if emptyLibrary {
                    ContentUnavailableView("No Transcripts", systemImage: "text.bubble",
                                           description: Text(translator.savesTranscripts ? translator.history.storageNote(device: UIDevice.current.model)
                                               : String(localized: "Saving transcripts is off in Settings.")))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.hvGround)
            .navigationTitle("Transcripts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

private struct TranscriptRow: View {
    let transcript: Transcript

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(transcript.title).font(.headline)
            Text(transcript.summary).font(.footnote).foregroundStyle(Color.hvMuted)
            if let first = transcript.lines.first {
                Text(first.translation).font(.footnote).foregroundStyle(Color.hvMuted).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Follows the translator, so the session in progress keeps growing while it is open.
private struct LiveTranscriptDetail: View {
    let translator: LiveTranslator
    var query: String = ""

    var body: some View {
        TranscriptDetailView(transcript: translator.transcript, delete: nil, query: query)
    }
}
