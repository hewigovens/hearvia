import HearviaSession
import HearviaUI
import SwiftUI

struct EngineStatusLine: View {
    let translator: LiveTranslator
    let setup: TranslatorSetup?

    var body: some View {
        switch setup {
        case .needsKey:
            SettingsLink { Label("Add a \(translator.engine.title) key in Settings", systemImage: "key") }
                .buttonStyle(.link).font(.caption)
        case .needsLocalModel:
            SettingsLink { Label("Choose a local model in Settings", systemImage: "desktopcomputer") }
                .buttonStyle(.link).font(.caption)
        case .needsModels:
            VStack(alignment: .leading, spacing: 6) {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage,
                                   translates: translator.engine == .onDevice)
            }
            .font(.caption)
            .padding(10)
            .background(Color.hvSurface, in: .rect(cornerRadius: 8))
        case .ready, nil:
            EmptyView()
        }
    }
}
