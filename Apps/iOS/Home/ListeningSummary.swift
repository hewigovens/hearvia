import HearviaUI
import SwiftUI

struct ListeningSummary: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                LevelBars(levels: model.levels)
                    .scaleEffect(0.75, anchor: .leading)
                    .frame(width: 60, alignment: .leading)
                if model.errorMessage.isEmpty {
                    Text("\(model.settings.input.title) · \(model.translation.languagePair) · \(model.translation.engine.shortTitle)")
                        .foregroundStyle(Color.hvMuted)
                } else {
                    Text(model.errorMessage).foregroundStyle(.red)
                }
                Spacer(minLength: 0)
            }
            .font(.footnote)
            .lineLimit(1)
            .padding(.horizontal, 4)
            if !model.pip.active {
                VStack(spacing: 12) {
                    if model.capture.running {
                        Text("Now open the app you want to watch or listen to. Subtitles follow you in a floating window.")
                            .font(.footnote).foregroundStyle(Color.hvMuted).multilineTextAlignment(.center)
                    }
                    Button { model.pip.start() } label: { Label("Float subtitles", systemImage: "pip.enter") }
                        .buttonStyle(HVButtonStyle(.secondary, height: 44))
                }
                .transition(.opacity)
            }
        }
    }
}
