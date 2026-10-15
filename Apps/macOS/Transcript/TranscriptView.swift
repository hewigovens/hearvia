import HearviaSession
import HearviaUI
import SwiftUI

struct TranscriptView: View {
    let translator: LiveTranslator

    var body: some View {
        TranscriptList(lines: translator.transcript.lines, originalFont: .callout, translationFont: .title3)
            .padding(20)
            .background(Color.hvGround)
            .foregroundStyle(Color.hvText)
            .toolbar {
                if !translator.transcript.isEmpty {
                    ShareLink(item: translator.transcript.text)
                    Button("Copy", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translator.transcript.text, forType: .string)
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 360)
    }
}
