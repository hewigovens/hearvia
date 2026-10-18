import HearviaUI
import SwiftUI

/// Listening on an iPhone Duo half-folded on a table: subtitles on the standing half for the room, the transcript and Stop on the half lying flat.
struct TabletopMode: View {
    let model: AppModel
    let fold: CGRect

    var body: some View {
        VStack(spacing: 0) {
            // The same inline layer as the home screen, so PiP can still start from it.
            SubtitlePreview(pip: model.pip)
                .aspectRatio(SubtitleRenderer.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: fold.minY)
                .background(Color.black.ignoresSafeArea(edges: .top))
                .accessibilityLabel("Live subtitles")
            Color.clear.frame(height: fold.height)
            HStack(alignment: .bottom, spacing: 16) {
                LiveTranscriptCard(translator: model.translation)
                VStack(spacing: 12) {
                    if !model.errorMessage.isEmpty {
                        Text(model.errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }
                    ListenButton(listening: true, busy: model.busy, size: 56) {
                        Task { await model.toggleListening() }
                    }
                }
                .frame(maxWidth: 160)
            }
            .padding(16)
            .frame(maxHeight: .infinity)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
