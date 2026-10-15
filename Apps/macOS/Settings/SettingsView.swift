import HearviaUI
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("OpenAI Realtime") {
                SecureField("API key", text: Bindable(model.translator).openAIKey)
                Text("Only used by the OpenAI Realtime translator. Kept in your Keychain.").font(.caption).foregroundStyle(Color.hvMuted)
            }
            Section("Gemini Live") {
                SecureField("API key", text: Bindable(model.translator).geminiKey)
                Text("Only used by the Gemini Live translator. Get a free key at [aistudio.google.com](https://aistudio.google.com/apikey). Kept in your Keychain.")
                    .font(.caption).foregroundStyle(Color.hvMuted)
            }
            Section("On-device models") {
                OnDeviceModelsView(source: model.translator.sourceLanguage, target: model.translator.targetLanguage)
            }
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Slider(value: $settings.overlayOpacity, in: 0 ... 1) { Text("Overlay background") }
                Toggle(isOn: $settings.menuBarOnly) {
                    Text("Show in menu bar only")
                    Text("Hides the Dock icon. Open Hearvia from the captions icon in the menu bar.")
                }
            }
            Section("Diagnostics") {
                Text("\(model.translator.status.label) · sent \(model.translator.stats.chunksSent) × 200 ms · \(model.translator.stats.deltas) deltas · \(model.translator.stats.reconnects) reconnects")
                    .font(.caption).monospacedDigit().textSelection(.enabled)
                Text("Launch with --verbose to log JSON events to stdout.").font(.caption).foregroundStyle(Color.hvMuted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.hvGround)
        .tint(.hvAccent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
