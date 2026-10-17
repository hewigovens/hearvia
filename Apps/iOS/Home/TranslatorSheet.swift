import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

struct TranslatorSheet: View {
    let translator: LiveTranslator
    let openSettings: () -> Void

    var body: some View {
        TileSheet(title: "Translator") {
            ForEach(EngineKind.allCases) { engine in
                ChoiceRow(symbol: engine.symbol, title: engine.title, detail: engine.tagline, selected: translator.engine == engine) {
                    Task { await translator.setEngine(engine) }
                }
            }
            EngineStatus(translator: translator, openSettings: openSettings)
        }
    }
}
