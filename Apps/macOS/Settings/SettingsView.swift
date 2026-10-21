import HearviaSession
import HearviaUI
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings(translator: model.translator) }
            Tab("Translators", systemImage: "character.bubble") { TranslatorSettings(translator: model.translator) }
            Tab("Overlay", systemImage: "captions.bubble") { OverlaySettings() }
            Tab("Diagnostics", systemImage: "stethoscope") { DiagnosticsSettings(translator: model.translator) }
        }
        .tint(.hvAccent)
    }
}

private struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.hvGround)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @Bindable var translator: LiveTranslator
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsPane {
            Section {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $settings.menuBarOnly) {
                    Text("Show in menu bar only")
                    Text("Open Hearvia from the menu bar icon.")
                }
            }
            Section {
                Toggle(isOn: $translator.savesTranscripts) {
                    Text("Save transcripts")
                }
                Toggle(isOn: Bindable(translator.history).syncsWithICloud) {
                    Text("Sync with iCloud")
                    Text(translator.history.storageNote(device: "Mac"))
                }
                Button("Delete All Transcripts", role: .destructive) { translator.history.deleteAll() }
                    .disabled(translator.history.transcripts.isEmpty)
            }
        }
    }
}

private struct TranslatorSettings: View {
    @Bindable var translator: LiveTranslator

    var body: some View {
        SettingsPane {
            Section {
                APIKeyField(.realtime, prompt: "API key", key: $translator.openAIKey)
            } header: { Text("OpenAI Realtime") } footer: {
                Text("Checked with OpenAI, then stored in your Keychain.").foregroundStyle(Color.hvMuted)
            }
            Section {
                APIKeyField(.gemini, prompt: "API key", key: $translator.geminiKey)
            } header: { Text("Gemini Live") } footer: {
                Text("Free key at [aistudio.google.com](https://aistudio.google.com/apikey). Checked with Google, then stored in your Keychain.")
                    .foregroundStyle(Color.hvMuted)
            }
            Section("On-device models") {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
            }
            Section {
                LocalModelSettingsView(translator: translator)
            } header: { Text("Local LLM (experimental)") } footer: {
                Text("Sends each finished sentence to your OpenAI-compatible server: Ollama, LM Studio, Unsloth Studio and others.")
                    .foregroundStyle(Color.hvMuted)
            }
        }
    }
}

private struct OverlaySettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsPane {
            Section {
                Toggle("Show the subtitle overlay", isOn: $settings.overlayVisible)
                Picker("Large text", selection: $settings.originalLarge) {
                    Text("Translation").tag(false)
                    Text("Original speech").tag(true)
                }
                .pickerStyle(.segmented)
                Toggle(settings.originalLarge ? "Show translation" : "Show original speech", isOn: $settings.showsOriginal)
                Toggle(isOn: $settings.clickThrough) {
                    Text("Click-through")
                    Text("Clicks reach the app below; the overlay can't be moved.")
                }
            }
            Section {
                Slider(value: $settings.overlayFontSize, in: AppSettings.overlayFontSizeRange) { Text("Text size") }
                Slider(value: $settings.overlayOpacity, in: 0 ... 1) { Text("Background") }
            }
        }
    }
}

private struct DiagnosticsSettings: View {
    let translator: LiveTranslator

    var body: some View {
        SettingsPane {
            Section {
                Text("\(translator.status.label) · sent \(translator.stats.chunksSent) × 200 ms · \(translator.stats.deltas) deltas · \(translator.stats.reconnects) reconnects")
                    .font(.caption).monospacedDigit().textSelection(.enabled)
            } footer: {
                Text("Launch with --verbose to log JSON events to stdout.").foregroundStyle(Color.hvMuted)
            }
        }
    }
}
