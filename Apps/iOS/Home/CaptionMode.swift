import HearviaUI
import SwiftUI

/// Listening in landscape without a fold (iPhone, iPad): the subtitles fill the screen for anyone nearby to read.
struct CaptionMode: View {
    let model: AppModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()
            // The same inline layer as the home screen, so PiP can still start from it.
            SubtitlePreview(pip: model.pip)
                .aspectRatio(SubtitleRenderer.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Live subtitles")
            if !model.errorMessage.isEmpty {
                Text(model.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            ListenButton(listening: true, busy: model.busy, size: 44) {
                Task { await model.toggleListening() }
            }
            .padding(16)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
