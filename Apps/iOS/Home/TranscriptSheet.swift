import HearviaSession
import HearviaUI
import SwiftUI

/// Finished sentences of the current or last session, to scroll back through or share.
struct TranscriptSheet: View {
    let translator: LiveTranslator

    var body: some View {
        let transcript = translator.transcript
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transcript").font(.title3.weight(.semibold))
                Spacer()
                if !transcript.isEmpty {
                    ShareLink(item: transcript.text) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share transcript")
                }
            }
            .frame(minHeight: 44)
            TranscriptList(lines: transcript.lines, translationFont: .body)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
