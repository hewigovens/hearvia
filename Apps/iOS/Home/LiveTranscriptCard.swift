import HearviaSession
import HearviaUI
import SwiftUI

/// Beside the subtitles on a wide screen: the session's finished sentences as they arrive.
struct LiveTranscriptCard: View {
    let translator: LiveTranslator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transcript").font(.headline)
            TranscriptList(lines: translator.transcript.lines, translationFont: .body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvSurface, in: .rect(cornerRadius: 22, style: .continuous))
    }
}
