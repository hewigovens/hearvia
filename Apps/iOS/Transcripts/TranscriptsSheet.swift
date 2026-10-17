import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptsSheet: View {
    let translator: LiveTranslator
    @Environment(\.dismiss) private var dismiss

    private var saved: [Transcript] {
        translator.history.transcripts.filter { !translator.isActive || $0.id != translator.transcript.id } // In progress is "Now".
    }

    var body: some View {
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
            .overlay {
                if saved.isEmpty, !translator.isActive {
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
        .presentationDetents([.medium, .large])
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
