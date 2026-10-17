import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// The translators, and what the chosen one still needs.
struct TranslatorSheet: View {
    let translator: LiveTranslator
    let openSettings: () -> Void

    var body: some View {
        TileSheet(title: "Translator") {
            ForEach(translator.engines) { engine in
                ChoiceRow(symbol: engine.symbol, title: engine.title, detail: detail(engine), selected: translator.engine == engine) {
                    Task { await translator.setEngine(engine) }
                }
            }
            EngineStatus(translator: translator, openSettings: openSettings)
        }
    }

    private func detail(_ engine: EngineKind) -> String {
        engine == .gemma && !BackgroundTranslation.isSupported ? "Offline · only while Hearvia is open" : engine.tagline
    }
}
