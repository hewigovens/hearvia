import HearviaUI
import SwiftUI

/// Finished sentences while listening, with Share and a shortcut to the floating window.
struct TranscriptCard: View {
    let model: AppModel

    var body: some View {
        let transcript = model.translation.transcript
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Text("TRANSCRIPT").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
                Spacer()
                if !transcript.isEmpty {
                    ShareLink(item: transcript.text) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share transcript")
                }
                if !model.pip.active {
                    Button { model.pip.start() } label: { Label("Float", systemImage: "pip.enter") }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(minHeight: 44)
            if model.capture.running, !model.pip.active, transcript.isEmpty {
                Text("Now open the app you want to watch or listen to. Subtitles follow you in a floating window.")
                    .font(.footnote).foregroundStyle(Color.hvMuted)
            } else {
                TranscriptList(lines: transcript.lines, translationFont: .body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvSurface, in: .rect(cornerRadius: 20, style: .continuous))
    }
}
