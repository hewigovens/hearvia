import HearviaSession
import HearviaUI
import SwiftUI

/// What the chosen translator still needs, with the fix inline; nothing once it is ready.
struct EngineStatusLine: View {
    let translator: LiveTranslator
    @State private var modelsMissing = false

    var body: some View {
        Group {
            if translator.engine.isCloud, translator.apiKey.isEmpty {
                SettingsLink { Label("Add a \(translator.engine.title) key in Settings", systemImage: "key") }
                    .buttonStyle(.link).font(.caption)
            } else if !translator.engine.isCloud, modelsMissing {
                VStack(alignment: .leading, spacing: 6) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                }
                .font(.caption)
                .padding(10)
                .background(Color.hvSurface, in: .rect(cornerRadius: 8))
            }
        }
        .task(id: translator.readinessKey) {
            modelsMissing = translator.engine.isCloud ? false : await !translator.isReady()
        }
    }
}
