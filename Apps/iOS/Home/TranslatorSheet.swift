import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// The two translators, and what the chosen one still needs.
struct TranslatorSheet: View {
    let translator: LiveTranslator
    let openSettings: () -> Void

    var body: some View {
        TileSheet(title: "Translator") {
            ForEach(EngineKind.allCases) { engine in
                ChoiceRow(symbol: engine.symbol, title: engine.title,
                          detail: engine == .onDevice ? "Free · private · works offline" : "Fastest · best quality · ~$2/hour",
                          selected: translator.engine == engine) {
                    Task { await translator.setEngine(engine) }
                }
            }
            EngineStatus(translator: translator, openSettings: openSettings)
        }
    }
}
