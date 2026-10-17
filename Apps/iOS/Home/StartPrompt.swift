import HearviaUI
import SwiftUI

/// Under the listen button while not listening: what a tap does, what iOS is waiting for, or what went wrong.
struct StartPrompt: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 6) {
            if model.capture.pending {
                Text("Tap **Share Entire Screen** on the iOS sheet. Hearvia only uses the sound.")
                    .font(.subheadline)
            } else if model.micStarting {
                Text("Starting the microphone…").font(.subheadline)
            } else {
                Text("Tap to start").font(.title3.weight(.semibold))
                Text("Other apps keep playing. Hearvia never plays sound.")
                    .font(.footnote).foregroundStyle(Color.hvMuted)
                if model.translation.engine == .gemma, !model.backgroundTranslation.isSupported {
                    Text("Keep Hearvia open for TranslateGemma on this device.")
                        .font(.footnote).foregroundStyle(Color.hvMuted)
                }
            }
            if !model.errorMessage.isEmpty {
                Text(model.errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}
