import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptCard: View {
    let translator: LiveTranslator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRANSCRIPT").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
                Spacer()
                if !translator.transcript.isEmpty {
                    ShareLink(item: translator.transcript.text) { Text("Share").font(.subheadline) }
                }
            }
            TranscriptList(lines: translator.transcript.lines)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }
}
