import HearviaSession
import HearviaUI
import SwiftUI

struct TranslatorSettingsView: View {
    @Bindable var translator: LiveTranslator

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    APIKeyField(.realtime, prompt: "sk-…", key: $translator.openAIKey)
                } label: { SettingsIcon("waveform", .teal) }
            } header: { Text("OpenAI Realtime") } footer: {
                Text("Checked with OpenAI, then stored in your Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                LabeledContent {
                    APIKeyField(.gemini, prompt: "API key", key: $translator.geminiKey)
                } label: { SettingsIcon("sparkle", .blue) }
            } header: { Text("Gemini Live") } footer: {
                Text("Free key at [aistudio.google.com](https://aistudio.google.com/apikey). Checked with Google, then stored in your Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
            } header: { Text("On-device models") } footer: {
                Text("Download once, then use offline.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                LocalModelSettingsView(translator: translator)
            } header: { Text("Local LLM (experimental)") } footer: {
                Text("Sends each finished sentence to your OpenAI-compatible server on the same network, such as http://my-mac.local:11434/v1.")
            }
            .listRowBackground(Color.hvSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.hvGround)
        .navigationTitle("Translators")
        .navigationBarTitleDisplayMode(.inline)
    }
}
