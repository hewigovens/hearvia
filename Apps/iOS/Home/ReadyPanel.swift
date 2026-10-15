import HearviaKit
import SwiftUI

/// Everything chosen before listening: source, languages, translator, original-speech toggle.
struct ReadyPanel: View {
    let model: AppModel
    let openSettings: () -> Void
    @Environment(AppSettings.self) private var settings

    private var translator: LiveTranslator {
        model.translation
    }

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 14) {
            if model.capture.pending {
                Card {
                    Label("Waiting for permission", systemImage: "hand.tap").font(.headline)
                    Text("Tap **Share Entire Screen** on the iOS sheet. Hearvia only uses the sound.")
                        .font(.subheadline).foregroundStyle(Color.hvMuted)
                }
            }
            SegmentedChoice(selection: $settings.input, options: InputSource.allCases, title: \.title) {
                $0 == .microphone ? "mic" : "square.grid.2x2"
            }
            .disabled(model.capture.pending || model.micStarting)
            LanguageCard(translator: translator)
            HStack(spacing: 10) {
                ForEach(TranslationEngine.allCases) { engine in
                    EngineCard(engine: engine, selected: translator.engine == engine) {
                        Task { await translator.setEngine(engine) }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            EngineStatus(translator: translator, openSettings: openSettings)
            Toggle("Also show original speech", isOn: $settings.showsOriginal)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }
}
