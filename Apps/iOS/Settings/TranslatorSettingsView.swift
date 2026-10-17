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
                Text("Only used by the OpenAI Realtime translator. Kept in this iPhone's Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                LabeledContent {
                    SecureField("AIza…", text: $translator.geminiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } label: { SettingsIcon("sparkle", .blue) }
            } header: { Text("Gemini Live") } footer: {
                Text("Only used by the Gemini Live translator. Get a free key at [aistudio.google.com](https://aistudio.google.com/apikey). Kept in this iPhone's Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
            } header: { Text("On-device models") } footer: {
                Text("For the languages chosen on the home screen. Downloaded once, then work offline.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                LocalModelSettingsView(translator: translator)
            } header: { Text("Local LLM (experimental)") } footer: {
                Text("Hearvia recognizes speech on this iPhone, then sends each finished sentence to this server for translation: Ollama, LM Studio, Unsloth Studio or another OpenAI-compatible server. Use your Mac's address on the same network (such as http://my-mac.local:11434/v1), with the server set to accept network connections.")
            }
            .listRowBackground(Color.hvSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.hvGround)
        .navigationTitle("Translators")
        .navigationBarTitleDisplayMode(.inline)
    }
}
