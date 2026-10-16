import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// Listen to · Languages · Translator, each a menu of its choices.
struct ControlTiles: View {
    @Bindable var model: AppModel
    @State private var ready: Bool?

    private var translator: LiveTranslator {
        model.translator
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu { sourceChoices } label: {
                ControlTile(symbol: model.source.symbol, caption: "Listen to", value: model.source.label)
            }
            Menu { languageChoices } label: {
                ControlTile(symbol: "character.bubble", caption: "Languages", value: translator.languagePair, wraps: false)
            }
            Menu { engineChoices } label: {
                ControlTile(symbol: translator.engine.symbol, caption: "Translator", value: translator.engine.title, ready: ready)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: translator.readinessKey) { ready = await translator.isReady() }
    }

    @ViewBuilder private var sourceChoices: some View {
        Picker("Listen to", selection: $model.source) {
            Label("All system audio", systemImage: "speaker.wave.2").tag(CaptureSource.allApps)
            Section("Apps") {
                ForEach(model.processes.sorted { $0.isOutputting && !$1.isOutputting }) { process in
                    Text(process.isOutputting ? "\(process.name) — playing audio" : process.name).tag(CaptureSource.process(process))
                }
            }
            Label("Microphone", systemImage: "mic").tag(CaptureSource.microphone)
        }
        .pickerStyle(.inline)
        Divider()
        Text("Browser audio? Choose All system audio.")
        Button("Refresh App List", systemImage: "arrow.clockwise") { model.refreshProcesses() }
    }

    @ViewBuilder private var languageChoices: some View {
        if translator.engine.detectsSpokenLanguage {
            Text("Spoken language: detected automatically")
        } else {
            Picker("Spoken", selection: Binding(get: { translator.sourceLanguage },
                                                set: { language in Task { await translator.setSourceLanguage(language) } })) {
                ForEach(OnDeviceLanguages.shared.spokenChoices(for: translator.engine, including: translator.sourceLanguage), id: \.self) {
                    Text(LanguageName.of($0)).tag($0)
                }
            }
            .pickerStyle(.menu)
        }
        Picker("Subtitles", selection: Binding(get: { translator.targetLanguage },
                                               set: { language in Task { await translator.setTargetLanguage(language) } })) {
            ForEach(OnDeviceLanguages.shared.subtitleChoices(for: translator.engine, including: translator.targetLanguage), id: \.self) {
                Text(LanguageName.of($0)).tag($0)
            }
        }
        .pickerStyle(.menu)
        if !translator.engine.detectsSpokenLanguage {
            Button("Swap Languages", systemImage: "arrow.left.arrow.right") {
                let spoken = translator.sourceLanguage, target = translator.targetLanguage
                Task {
                    await translator.setSourceLanguage(target)
                    await translator.setTargetLanguage(spoken)
                }
            }
        }
    }

    @ViewBuilder private var engineChoices: some View {
        Picker("Translator", selection: Binding(get: { translator.engine }, set: { engine in Task { await translator.setEngine(engine) } })) {
            ForEach(translator.engines) { Text("\($0.title) — \($0.tagline)").tag($0) }
        }
        .pickerStyle(.inline)
        Divider()
        SettingsLink { Text("Translator Settings…") }
    }
}
