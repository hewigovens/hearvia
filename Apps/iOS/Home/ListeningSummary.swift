import HearviaUI
import SwiftUI

/// One line under the live subtitles: input level, source, languages and translator, or a translator error.
struct ListeningSummary: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            LevelBars(levels: model.levels)
                .scaleEffect(0.75, anchor: .leading)
                .frame(width: 60, alignment: .leading)
            if model.errorMessage.isEmpty {
                Text("\(model.settings.input.title) · \(model.translation.languagePair) · \(model.translation.engine.title)")
                    .foregroundStyle(Color.hvMuted)
            } else {
                Text(model.errorMessage).foregroundStyle(.red)
            }
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .lineLimit(1)
        .padding(.horizontal, 4)
    }
}
