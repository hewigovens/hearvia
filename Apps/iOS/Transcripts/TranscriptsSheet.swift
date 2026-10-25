import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptsSheet: View {
    let translator: LiveTranslator
    private var saved: [Transcript] {
        translator.savedTranscripts
    }

    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var selection: UUID?
    @State private var query = ""

    private var needle: String {
        TranscriptSearch.needle(query)
    }

    private var filteredSaved: [Transcript] {
        saved.filter { $0.matches(query) }
    }

    private var liveMatches: Bool {
        translator.isActive && translator.transcript.matches(query)
    }

    private var nothingMatches: Bool {
        !needle.isEmpty && !liveMatches && filteredSaved.isEmpty
    }

    private var emptyLibrary: Bool {
        needle.isEmpty && saved.isEmpty && !translator.isActive
    }

    var body: some View {
        if widthClass == .regular {
            split
        } else {
            stack
        }
    }

    private var stack: some View {
        NavigationStack {
            List {
                if liveMatches {
                    Section("Now") {
                        NavigationLink { LiveTranscriptDetail(translator: translator, query: query) } label: { TranscriptRow(transcript: translator.transcript) }
                    }
                }
                if !filteredSaved.isEmpty {
                    Section("Earlier") {
                        ForEach(filteredSaved) { transcript in
                            NavigationLink {
                                TranscriptDetailView(transcript: transcript, delete: { translator.history.delete(transcript) }, query: query)
                            } label: {
                                TranscriptRow(transcript: transcript)
                            }
                        }
                        .onDelete { offsets in offsets.map { filteredSaved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, emptyLibrary: emptyLibrary, noMatches: nothingMatches))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search transcripts"))
        }
        .presentationDetents([.medium, .large])
    }

    /// Wide screens (the open iPhone Duo, iPad): the list beside the transcript, like the Mac window.
    private var split: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if liveMatches {
                    Section("Now") { TranscriptRow(transcript: translator.transcript).tag(translator.transcript.id) }
                }
                if !filteredSaved.isEmpty {
                    Section("Earlier") {
                        ForEach(filteredSaved) { TranscriptRow(transcript: $0).tag($0.id) }
                            .onDelete { offsets in offsets.map { filteredSaved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, emptyLibrary: emptyLibrary, noMatches: false))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search transcripts"))
        } detail: {
            if nothingMatches {
                ContentUnavailableView("No Matches", systemImage: "magnifyingglass",
                                       description: Text("No transcript has those words."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.hvGround)
            } else if translator.isActive, selection == translator.transcript.id {
                LiveTranscriptDetail(translator: translator, query: query)
            } else if let transcript = saved.first(where: { $0.id == selection }) {
                TranscriptDetailView(transcript: transcript, delete: {
                    translator.history.delete(transcript)
                    selection = nil
                }, closesOnDelete: false, query: query)
                    .id(transcript.id)
            }
        }
        .onAppear { selection = selection ?? (translator.isActive ? translator.transcript.id : saved.first?.id) }
        .onChange(of: query) { old, new in
            guard TranscriptSearch.needle(old) != TranscriptSearch.needle(new) else { return }
            reconcileSelection()
        }
        .presentationSizing(.page)
    }

    private func reconcileSelection() {
        if needle.isEmpty {
            if let selection, selectionExists(selection) { return }
            selection = translator.isActive ? translator.transcript.id : saved.first?.id
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
        (translator.isActive && translator.transcript.id == id) || saved.contains { $0.id == id }
    }

    private func selectionMatches(_ id: UUID) -> Bool {
        (liveMatches && translator.transcript.id == id) || filteredSaved.contains { $0.id == id }
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
