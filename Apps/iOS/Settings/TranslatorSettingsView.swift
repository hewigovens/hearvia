import HearviaSession
import HearviaUI
import SwiftUI

/// API keys for the cloud translators and the on-device models, one page under Settings.
struct TranslatorSettingsView: View {
    @Bindable var translator: LiveTranslator

    var body: some View {
        Form {
            Section {
                SecureField("sk-…", text: $translator.openAIKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: { Text("OpenAI Realtime") } footer: {
                Text("Only used by the OpenAI Realtime translator. Kept in this iPhone's Keychain.")
            }
            .listRowBackground(Color.hvSurface)

            Section {
                SecureField("AIza…", text: $translator.geminiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
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

            if let gemma = translator.downloadable(for: .gemma), gemma.isSupported {
                Section {
                    DownloadableEngineRow(gemma)
                } footer: {
                    Text("Google's open translation model, run on this iPhone with no internet. \(BackgroundTranslation.isSupported ? "Translation can continue behind other apps while iOS allows it. Open Hearvia to resume if it pauses." : "On this iPhone, translation pauses behind other apps.") [Gemma Terms of Use](https://ai.google.dev/gemma/terms).")
                }
                .listRowBackground(Color.hvSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.hvGround)
        .navigationTitle("Translators")
        .navigationBarTitleDisplayMode(.inline)
    }
}
