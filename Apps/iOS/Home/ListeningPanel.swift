import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// Live state while listening: input level, language pair, transcript, floating-window shortcut.
struct ListeningPanel: View {
    let model: AppModel

    private var translator: LiveTranslator {
        model.translation
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                LevelBars(levels: model.levels)
                Text(languagePair).font(.footnote).foregroundStyle(Color.hvMuted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            if model.capture.running, !model.pip.active {
                Text("Now open the app you want to watch or listen to. Subtitles follow you in a floating window.")
                    .font(.footnote).foregroundStyle(Color.hvMuted).frame(maxWidth: .infinity, alignment: .leading)
            }
            TranscriptCard(translator: translator)
            if !model.pip.active {
                Button { model.pip.start() } label: { Label("Show floating subtitles", systemImage: "pip.enter") }
                    .buttonStyle(HVButtonStyle(.secondary, height: 48))
            }
        }
    }

    private var languagePair: String {
        let spoken = translator.engine == .realtime ? "Auto" : LanguageName.short(translator.sourceLanguage)
        return "\(spoken) → \(LanguageName.short(translator.targetLanguage)) · \(translator.engine.title)"
    }
}
