import HearviaSession
import HearviaUI
import SwiftUI

struct TranslatorSettingsView: View {
    @Bindable var translator: LiveTranslator

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    SecureField("sk-…", text: $translator.openAIKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } label: { SettingsIcon("waveform", .teal) }
            } header: { Text("OpenAI Realtime") } footer: {
                Text("Stored in your Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                LabeledContent {
                    SecureField("AIza…", text: $translator.geminiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } label: { SettingsIcon("sparkle", .blue) }
            } header: { Text("Gemini Live") } footer: {
                Text("Free key at [aistudio.google.com](https://aistudio.google.com/apikey). Stored in your Keychain.")
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
