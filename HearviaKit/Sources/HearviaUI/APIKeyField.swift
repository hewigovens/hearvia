import HearviaCore
import HearviaEngines
import SwiftUI

/// Saves a cloud key only once it looks right and the provider accepts it; saving an empty field removes the key.
public struct APIKeyField: View {
    let engine: EngineKind
    let prompt: LocalizedStringKey
    @Binding var key: String
    @State private var draft = ""
    @State private var checking = false
    @State private var outcome: Outcome?

    private enum Outcome {
        case saved
        case failed(String)
    }

    public init(_ engine: EngineKind, prompt: LocalizedStringKey, key: Binding<String>) {
        self.engine = engine
        self.prompt = prompt
        _key = key
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SecureField(prompt, text: $draft)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .onSubmit { Task { await save() } }
                if checking {
                    ProgressView().controlSize(.small)
                } else if draft != key {
                    Button("Save") { Task { await save() } }
                }
            }
            Group {
                switch outcome {
                case .saved: Label("Checked and saved", systemImage: "checkmark.circle.fill").foregroundStyle(Color.hvReady)
                case let .failed(reason): Text(reason).foregroundStyle(.red)
                case nil: EmptyView()
                }
            }
            .font(.footnote)
        }
        .onAppear { draft = key }
        .onChange(of: draft) {
            if draft != key {
                outcome = nil
            }
        }
    }

    private func save() async {
        let candidate = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate != key, !checking else { return }
        if !candidate.isEmpty {
            checking = true
            defer { checking = false }
            do {
                try await APIKeyCheck(engine, key: candidate).verify()
            } catch {
                outcome = .failed(error.localizedDescription)
                return
            }
        }
        key = candidate
        draft = candidate
        outcome = candidate.isEmpty ? nil : .saved
    }
}
