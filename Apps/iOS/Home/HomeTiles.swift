import HearviaSession
import HearviaUI
import SwiftUI

struct HomeTiles: View {
    let model: AppModel
    let present: (HomePresentation) -> Void
    @Environment(AppSettings.self) private var settings
    @State private var ready: Bool?

    private var translator: LiveTranslator {
        model.translation
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { present(.source) } label: {
                ControlTile(symbol: settings.input.symbol, caption: "Listen to", value: settings.input.title)
            }
            .disabled(model.busy)
            Button { present(.languages) } label: {
                ControlTile(symbol: "character.bubble", caption: "Languages", value: translator.languagePair, wraps: false)
            }
            Button { present(.translator) } label: {
                ControlTile(symbol: translator.engine.symbol, caption: "Translator", value: translator.engine.shortTitle, ready: ready)
            }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: translator.readinessKey) { ready = await translator.isReady() }
    }
}
