import HearviaUI
import SwiftUI

/// Big subtitles for a room on an external display or an Apple TV over AirPlay, while listening with Hearvia in front; iOS mirrors the iPhone otherwise.
struct ExternalSubtitles: View {
    let model: AppModel
    let settings: AppSettings

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.height * 0.07 * settings.subtitleScale
            let lines = model.translation.subtitleLines(originalLarge: settings.originalLarge, showsSecond: settings.showsOriginal)
            VStack(spacing: size * 0.3) {
                Spacer(minLength: 0)
                if let second = lines.second {
                    newest(second.subtitleTail(300), size: size * 0.6, lineCount: 2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                newest(lines.main.isEmpty ? String(localized: "Listening…") : lines.main.subtitleTail(400), size: size, lineCount: 2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, proxy.size.width * 0.08)
            .padding(.bottom, proxy.size.height * 0.08)
        }
        .background(.black)
    }

    /// Keeps the newest words in view: the text grows from the bottom and older lines scroll off the top.
    private func newest(_ text: String, size: CGFloat, lineCount: Int) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: size))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .frame(height: UIFont.systemFont(ofSize: size).lineHeight * CGFloat(lineCount))
    }
}
