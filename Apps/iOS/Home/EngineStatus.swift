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
            if translator.engine.isCloud {
                if translator.apiKey.isEmpty {
                    Button(action: openSettings) {
                        Label("Add a \(translator.engine.title) key in Settings", systemImage: "key")
                    }
                    .font(.footnote)
                } else {
                    readyLine("Using your \(translator.engine.title) key")
                }
            } else if translator.engine == .local, translator.localModel.isEmpty {
                Button(action: openSettings) {
                    Label("Choose a local model in Settings", systemImage: "desktopcomputer")
                }
                .font(.footnote)
            } else if ready == true {
                readyLine(translator.engine == .local ? "Using \(translator.localModel)" : "Speech and translation models ready")
            } else if ready == nil {
                Label("Checking on-device models…", systemImage: "hourglass").font(.footnote).foregroundStyle(Color.hvMuted)
            } else {
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
            ready = nil
            guard !translator.engine.isCloud else { return }
            ready = await translator.isReady()
        }
    }

    private func readyLine(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hvReady) }
            .font(.footnote).foregroundStyle(Color.hvMuted)
    }
}
