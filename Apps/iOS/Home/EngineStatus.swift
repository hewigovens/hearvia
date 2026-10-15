import HearviaEngines
import HearviaSession
import HearviaUI
import SwiftUI

/// One line when the chosen translator is ready; otherwise what's missing, with the fix inline.
struct EngineStatus: View {
    let translator: LiveTranslator
    let openSettings: () -> Void
    @State private var ready: Bool?

    var body: some View {
        Group {
            if translator.engine == .realtime {
                if translator.apiKey.isEmpty {
                    Button(action: openSettings) {
                        Label("Add an OpenAI API key in Settings", systemImage: "key")
                    }
                    .font(.footnote)
                } else {
                    readyLine("Connected with your OpenAI API key")
                }
            } else if ready == true {
                readyLine("Speech and translation models ready")
            } else if ready == nil {
                Label("Checking on-device models…", systemImage: "hourglass").font(.footnote).foregroundStyle(Color.hvMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                        .font(.subheadline)
                }
                .padding(14)
                .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .task(id: "\(translator.engine.rawValue)\(translator.sourceLanguage)\(translator.targetLanguage)") {
            ready = nil
            guard translator.engine == .onDevice else { return }
            ready = await OnDeviceModels.isReady(from: translator.sourceLanguage, to: translator.targetLanguage)
        }
    }

    private func readyLine(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hvReady) }
            .font(.footnote).foregroundStyle(Color.hvMuted)
    }
}
