import HearviaCore
import HearviaUI
import SwiftUI

struct TranscriptDetailView: View {
    let transcript: Transcript
    let delete: (() -> Void)?
    /// Pops back to the list after a delete; a split view's detail column has nothing to pop to.
    var closesOnDelete = true
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
                if closesOnDelete {
                    dismiss()
                }
            }
        }
    }
}
