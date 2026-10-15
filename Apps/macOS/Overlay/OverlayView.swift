import HearviaKit
import SwiftUI

struct OverlayView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let translator = model.translator
        VStack(spacing: 6) {
            if settings.showsOriginal, !translator.source.isEmpty {
                bottomAligned(Text(Self.tail(translator.source, 300))
                    .font(.system(size: settings.overlayFontSize * 0.55))
                    .foregroundStyle(.white.opacity(0.7)))
                    .frame(height: ceil(settings.overlayFontSize * 0.55 * 1.25 * 2)) // two full lines of original speech
            }
            bottomAligned(Text(translator.translation.isEmpty ? placeholder : Self.tail(translator.translation, 400))
                .font(.system(size: settings.overlayFontSize, weight: .semibold))
                .foregroundStyle(.white))
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
        return model.capturing ? "Listening… (\(model.translator.state))" : "Hearvia — start capture in the main window"
    }

    /// Newest lines stay pinned to the bottom; older lines scroll off the top.
    /// A non-scrollable ScrollView gives the text unlimited height but clips it to the panel.
    private func bottomAligned(_ text: some View) -> some View {
        ScrollView {
            text.multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
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
