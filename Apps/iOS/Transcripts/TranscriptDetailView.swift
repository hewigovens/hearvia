import HearviaCore
import HearviaUI
import SwiftUI

/// One transcript, with export (a .txt named after its start time) and, for saved ones, delete.
struct TranscriptDetailView: View {
    let transcript: Transcript
    let delete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(transcript.summary).font(.footnote).foregroundStyle(Color.hvMuted)
            TranscriptList(lines: transcript.lines, translationFont: .body)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvGround)
        .navigationTitle(transcript.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if delete != nil {
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                }
                ShareLink(item: transcript, preview: SharePreview(transcript.title)) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(transcript.isEmpty)
            }
        }
        .confirmationDialog("Delete this transcript?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                delete?()
                dismiss()
            }
        }
    }
}
