import HearviaKit
import SwiftUI

struct TranscriptView: View {
    let translator: LiveTranslator
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TranscriptList(lines: translator.transcript, originalFont: .callout, translationFont: .title3)
            .padding(20)
            .background(Color.hvGround)
            .foregroundStyle(Color.hvText)
            .preferredColorScheme(settings.appearance.colorScheme)
            .toolbar {
                if !translator.transcript.isEmpty {
                    ShareLink(item: translator.transcriptText)
                    Button("Copy", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translator.transcriptText, forType: .string)
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 360)
    }
}
