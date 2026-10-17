import HearviaEngines
import HearviaSession
import SwiftUI

/// Address, optional key and model for the local model translator. Place inside a Form section.
public struct LocalModelSettingsView: View {
    @Bindable var translator: LiveTranslator
    @State private var models: [String] = []
    @State private var failure = ""

    public init(translator: LiveTranslator) {
        self.translator = translator
    }

    public var body: some View {
        Group {
            HStack {
                TextField("Server", text: $translator.localServerURL, prompt: Text("http://localhost:11434/v1"))
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                #endif
                Menu("Presets") {
                    ForEach(LocalModelServer.presets, id: \.name) { preset in
                        Button(preset.name) { translator.localServerURL = preset.baseURL }
                    }
                }
                .fixedSize()
            }
            SecureField("API key (Unsloth Studio only)", text: $translator.localKey)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
            Picker("Model", selection: $translator.localModel) {
                Text("Choose…").tag("")
                ForEach(models.contains(translator.localModel) || translator.localModel.isEmpty ? models : [translator.localModel] + models,
                        id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Text(failure.isEmpty ? "\(models.count) model\(models.count == 1 ? "" : "s") on this server" : failure)
                    .font(.footnote)
                    .foregroundStyle(failure.isEmpty ? Color.hvMuted : .red)
                Spacer()
                Button("Refresh") { Task { await refresh() } }
            }
        }
        .task(id: "\(translator.localServerURL)>\(translator.localKey)") { await refresh() }
    }

    private func refresh() async {
        do {
            models = try await translator.localServer.models()
            failure = ""
        } catch {
            models = []
            failure = error.localizedDescription
        }
    }
}
