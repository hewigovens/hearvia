import HearviaSession
import HearviaUI
import SwiftUI

/// Settings window: General, Translators, Overlay and Diagnostics tabs.
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

/// The look shared by every tab.
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
                    Text("Hides the Dock icon. Open Hearvia from the captions icon in the menu bar.")
                }
            }
            Section {
                Toggle(isOn: $translator.savesTranscripts) {
                    Text("Save transcripts")
                    Text("Kept on this Mac only. Open Transcripts to export or copy one.")
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
                SecureField("API key", text: $translator.openAIKey)
            } header: { Text("OpenAI Realtime") } footer: {
                Text("Only used by the OpenAI Realtime translator. Kept in your Keychain.").foregroundStyle(Color.hvMuted)
            }
            Section {
                SecureField("API key", text: $translator.geminiKey)
            } header: { Text("Gemini Live") } footer: {
                Text("Only used by the Gemini Live translator. Get a free key at [aistudio.google.com](https://aistudio.google.com/apikey). Kept in your Keychain.")
                    .foregroundStyle(Color.hvMuted)
            }
            Section("On-device models") {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
            }
            Section {
                LocalModelSettingsView(translator: translator)
            } header: { Text("Local model (experimental)") } footer: {
                Text("Hearvia recognizes speech on this Mac, then sends each finished sentence to this server for translation. Works with Ollama, LM Studio, Unsloth Studio or another OpenAI-compatible server.")
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
                Toggle("Show original speech", isOn: $settings.showsOriginal)
                Toggle(isOn: $settings.clickThrough) {
                    Text("Click-through")
                    Text("Clicks reach the app underneath; the overlay can't be dragged meanwhile.")
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
