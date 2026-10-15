import HearviaKit
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("OpenAI Realtime") {
                SecureField("API key", text: Bindable(model.translator).apiKey)
                Text("Only used by the OpenAI Realtime translator. Kept in your Keychain.").font(.caption).foregroundStyle(Color.hvMuted)
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
            }
            Section("Diagnostics") {
                Text("\(model.translator.state) · sent \(model.translator.chunksSent) × 200 ms · \(model.translator.deltas) deltas · \(model.translator.reconnects) reconnects")
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
