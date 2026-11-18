import HearviaSession
import HearviaUI
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings(model: model, translator: model.translator) }
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
    let model: AppModel
    @Bindable var translator: LiveTranslator
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsPane {
            Section {
                LabeledContent {
                    ThemePicker(selection: $settings.appearance)
                        .fixedSize()
                } label: { Label("Theme", systemImage: "paintpalette") }
                Toggle(isOn: $settings.menuBarOnly) {
                    Label("Show in menu bar only", systemImage: "menubar.rectangle")
                    Text("Open Hearvia from the menu bar icon.")
                }
            }
            Section {
                Toggle(isOn: Binding(get: { settings.warmCaptions }, set: { enabled in
                    if enabled {
                        settings.warmSource = model.source.savedSelection
                    }
                    settings.warmCaptions = enabled
                })) {
                    Label("Keep captions ready", systemImage: "waveform")
                    Text("Keeps the last 5 seconds on device.")
                }
                Toggle(isOn: $translator.savesTranscripts) {
                    Label("Save transcripts", systemImage: "doc.text")
                }
                Toggle(isOn: Bindable(translator.history).syncsWithICloud) {
                    Label("Sync with iCloud", systemImage: "icloud")
                    Text(translator.history.storageNote(device: "Mac"))
                }
                Button("Delete All Transcripts", systemImage: "trash", role: .destructive) { translator.history.deleteAll() }
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
            } header: { Text("Local LLM") } footer: {
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
                Toggle("Show the subtitle overlay", systemImage: "captions.bubble", isOn: $settings.overlayVisible)
                Picker("Large text", systemImage: "textformat.size.larger", selection: $settings.originalLarge) {
                    Text("Translation").tag(false)
                    Text("Original speech").tag(true)
                }
                .pickerStyle(.segmented)
                Toggle(settings.originalLarge ? "Show translation" : "Show original speech", systemImage: "character.bubble", isOn: $settings.showsOriginal)
                Toggle(isOn: $settings.twoLines) {
                    Label("Two lines at most", systemImage: "text.alignleft")
                    Text("Like film subtitles. Turn off to fill the overlay with more of what was said.")
                }
                Toggle(isOn: $settings.clickThrough) {
                    Label("Click-through", systemImage: "cursorarrow.rays")
                    Text("Clicks reach the app below; the overlay can't be moved.")
                }
            }
            Section {
                Slider(value: $settings.overlayFontSize, in: AppSettings.overlayFontSizeRange) { Label("Text size", systemImage: "textformat.size") }
                Slider(value: $settings.overlayOpacity, in: 0 ... 1) { Label("Background", systemImage: "circle.lefthalf.filled") }
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
