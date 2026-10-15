import HearviaKit
import SwiftUI

/// Pinned bottom bar: Start, Cancel (while the iOS picker or mic is starting) or Stop, plus errors.
struct ListenControls: View {
    let model: AppModel

    private var busy: Bool {
        model.listening || model.capture.pending || model.micStarting
    }

    var body: some View {
        VStack(spacing: 8) {
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            if model.listening {
                Button { Task { await model.stopListening() } } label: { Label("Stop Listening", systemImage: "stop.fill") }
                    .buttonStyle(HVButtonStyle(.stop))
            } else if busy {
                Button { Task { await model.stopListening() } } label: { Text("Cancel") }
                    .buttonStyle(HVButtonStyle(.secondary))
            } else {
                Button { model.startListening() } label: { Label("Start Listening", systemImage: "play.fill") }
                    .buttonStyle(HVButtonStyle(.primary))
                Text("Other apps keep playing. Hearvia never plays sound.")
                    .font(.footnote).foregroundStyle(Color.hvMuted)
            }
        }
        .accessibilityIdentifier("listenToggle")
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.hvGround)
    }

    private var errorMessage: String {
        let message = [model.translation.error, model.capture.error, model.micError].filter { !$0.isEmpty }.joined(separator: "\n")
        if message.contains("invalid_api_key") {
            return "The OpenAI key was rejected. Check it in Settings."
        }
        if message.contains("insufficient_quota") {
            return "The OpenAI account has no remaining credit. Try the on-device translator."
        }
        return message
    }
}
