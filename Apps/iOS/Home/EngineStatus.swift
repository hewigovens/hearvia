import HearviaEngines
import HearviaSession
import HearviaUI
import SwiftUI

struct EngineStatus: View {
    let translator: LiveTranslator
    let openSettings: () -> Void
    @State private var checked: TranslatorSetup?

    var body: some View {
        Group {
            switch translator.knownSetup ?? checked {
            case .needsKey:
                Button(action: openSettings) {
                    Label("Add a \(translator.engine.title) key in Settings", systemImage: "key")
                }
                .font(.footnote)
            case .needsLocalModel:
                Button(action: openSettings) {
                    Label("Choose a local model in Settings", systemImage: "desktopcomputer")
                }
                .font(.footnote)
            case .ready:
                Label { Text(readyText) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hvReady) }
                    .font(.footnote).foregroundStyle(Color.hvMuted)
            case nil:
                Label("Checking on-device models…", systemImage: "hourglass").font(.footnote).foregroundStyle(Color.hvMuted)
            case .needsModels:
                VStack(alignment: .leading, spacing: 8) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage,
                                       translates: translator.engine == .onDevice)
                        .font(.subheadline)
                }
                .padding(14)
                .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .task(id: translator.readinessKey) {
            checked = nil
            checked = await translator.checkSetup()
        }
    }

    private var readyText: LocalizedStringKey {
        switch translator.engine {
        case .realtime, .gemini: "Using your \(translator.engine.title) key"
        case .local: "Using \(translator.localModel)"
        case .onDevice: "Speech and translation models ready"
        }
    }
}
