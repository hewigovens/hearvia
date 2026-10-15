import HearviaKit
import SwiftUI

/// One line when the translator is ready; otherwise the missing model or key, with the fix inline.
struct EngineStatusLine: View {
    let translator: LiveTranslator
    @State private var ready: Bool?

    var body: some View {
        Group {
            if translator.engine == .realtime {
                if translator.apiKey.isEmpty {
                    SettingsLink { Label("Add an OpenAI API key in Settings", systemImage: "key") }
                        .buttonStyle(.link).font(.caption)
                } else {
                    line("Using your OpenAI API key", ok: true)
                }
            } else if ready == nil {
                line("Checking on-device models…", ok: false)
            } else if ready == true {
                line("Models ready", ok: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                }
                .font(.caption)
                .padding(10)
                .background(Color.hvSurface, in: .rect(cornerRadius: 8))
            }
        }
        .task(id: "\(translator.engine.rawValue)\(translator.sourceLanguage)\(translator.targetLanguage)") {
            ready = nil
            guard translator.engine == .onDevice else { return }
            ready = await OnDeviceModels.isReady(from: translator.sourceLanguage, to: translator.targetLanguage)
        }
    }

    private func line(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.hvReady : Color.hvMuted).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(Color.hvMuted)
        }
    }
}
