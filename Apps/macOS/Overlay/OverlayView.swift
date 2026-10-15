import AppKit
import SwiftUI

struct OverlayView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let translator = model.translator
        let originalSize = settings.overlayFontSize * 0.55
        VStack(spacing: 2) {
            Spacer(minLength: 0)
            if settings.showsOriginal, !translator.source.isEmpty {
                // Two whole lines: a fraction of a line more would show a sliver of the line above.
                tail(Text(Self.tail(translator.source, 300))
                    .font(.system(size: originalSize))
                    .foregroundStyle(.white.opacity(0.7)), fade: 0)
                    .frame(maxHeight: 2 * Self.lineHeight(ofSystemFontSize: originalSize))
                    .layoutPriority(2) // Keeps its two lines when the translation overflows.
            }
            tail(Text(translator.translation.isEmpty ? placeholder : Self.tail(translator.translation, 400))
                .font(.system(size: settings.overlayFontSize, weight: .semibold))
                .foregroundStyle(.white), fade: 0.4 * Self.lineHeight(ofSystemFontSize: settings.overlayFontSize))
                .layoutPriority(1)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(settings.overlayOpacity)))
        .shadow(color: .black.opacity(0.4), radius: 2)
    }

    private var placeholder: String {
        if !model.translator.error.isEmpty {
            return model.translator.error
        }
        return model.capturing ? "Listening… (\(model.translator.status.label))" : "Hearvia — start capture in the main window"
    }

    /// Text at its natural height when it fits, so original and translation sit together at the bottom;
    /// otherwise the newest lines pinned to the bottom of the space offered, older lines clipped off the top.
    /// The non-scrollable ScrollView gives the text unlimited height but clips it; `fade` hides the part-line
    /// clipped at the top, since the space offered isn't a whole number of lines.
    private func tail(_ text: some View, fade: CGFloat) -> some View {
        let centered = text.multilineTextAlignment(.center).frame(maxWidth: .infinity)
        return ViewThatFits(in: .vertical) {
            centered.fixedSize(horizontal: false, vertical: true)
            ScrollView {
                centered
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: fade)
                    Color.black
                }
            }
        }
    }

    static func lineHeight(ofSystemFontSize size: CGFloat) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: size))
    }

    static func tail(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        var tail = text.suffix(limit)
        if let space = tail.firstIndex(of: " "), tail.distance(from: tail.startIndex, to: space) < 20 {
            tail = tail[tail.index(after: space)...]
        }
        return String(tail)
    }
}
