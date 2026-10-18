import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptsSheet: View {
    let translator: LiveTranslator
    private var saved: [Transcript] {
        translator.history.transcripts.filter { !translator.isActive || $0.id != translator.transcript.id } // In progress is "Now".
    }

    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var selection: UUID?

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
                if translator.isActive {
                    Section("Now") {
                        NavigationLink { LiveTranscriptDetail(translator: translator) } label: { TranscriptRow(transcript: translator.transcript) }
                    }
                }
                if !saved.isEmpty {
                    Section("Earlier") {
                        ForEach(saved) { transcript in
                            NavigationLink { TranscriptDetailView(transcript: transcript) { translator.history.delete(transcript) } } label: {
                                TranscriptRow(transcript: transcript)
                            }
                        }
                        .onDelete { offsets in offsets.map { saved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, isEmpty: saved.isEmpty && !translator.isActive))
        }
        .presentationDetents([.medium, .large])
    }

    /// Wide screens (the open iPhone Duo, iPad): the list beside the transcript, like the Mac window.
    private var split: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if translator.isActive {
                    Section("Now") { TranscriptRow(transcript: translator.transcript).tag(translator.transcript.id) }
                }
                if !saved.isEmpty {
                    Section("Earlier") {
                        ForEach(saved) { TranscriptRow(transcript: $0).tag($0.id) }
                            .onDelete { offsets in offsets.map { saved[$0] }.forEach(translator.history.delete) }
                    }
                }
            }
            .modifier(TranscriptListStyle(translator: translator, isEmpty: saved.isEmpty && !translator.isActive))
        } detail: {
            if translator.isActive, selection == translator.transcript.id {
                LiveTranscriptDetail(translator: translator)
            } else if let transcript = saved.first(where: { $0.id == selection }) {
                TranscriptDetailView(transcript: transcript, delete: {
                    translator.history.delete(transcript)
                    selection = nil
                }, closesOnDelete: false)
                    .id(transcript.id)
            }
        }
        .onAppear { selection = selection ?? (translator.isActive ? translator.transcript.id : saved.first?.id) }
        .presentationSizing(.page)
    }
}

private struct TranscriptListStyle: ViewModifier {
    let translator: LiveTranslator
    let isEmpty: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEmpty {
                    ContentUnavailableView("No Transcripts", systemImage: "text.bubble",
                                           description: Text(translator.savesTranscripts ? "Each listening session is kept here, on this iPhone."
                                               : "Saving transcripts is off in Settings."))
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

    var body: some View {
        TranscriptDetailView(transcript: translator.transcript, delete: nil)
    }
}
