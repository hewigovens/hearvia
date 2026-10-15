import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// The two translators side by side, and what the chosen one still needs.
struct TranslatorSheet: View {
    let translator: LiveTranslator
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Translator").font(.title3.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(EngineKind.allCases) { engine in
                    EngineCard(engine: engine, selected: translator.engine == engine) {
                        Task { await translator.setEngine(engine) }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            EngineStatus(translator: translator, openSettings: openSettings)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .presentationDetents([.medium])
    }
}
