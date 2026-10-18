import AppKit
import HearviaUI
import SwiftUI

struct OverlayView: View {
    let model: AppModel
    let pointer: OverlayPointer
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let live = model.capturing
        subtitles
            .allowsHitTesting(false)
            .padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: live ? .infinity : 600, maxHeight: live ? .infinity : 96)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(settings.overlayOpacity)))
            .overlay {
                if pointer.inside, !settings.clickThrough {
                    OverlayButtons(model: model).transition(.opacity)
                }
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
            .gesture(WindowDragGesture())
            .pointerStyle(.grabIdle)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(duration: 0.5, bounce: 0.15), value: live)
            .animation(.easeOut(duration: 0.2), value: pointer.inside)
    }

    @ViewBuilder private var subtitles: some View {
        let lines = model.translator.subtitleLines(originalLarge: settings.originalLarge, showsSecond: settings.showsOriginal)
        if !model.capturing || lines.main.isEmpty {
            Text(placeholder)
                .font(.system(size: min(settings.overlayFontSize, 22), weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: model.capturing ? .bottom : .center)
        } else {
            let originalSize = settings.overlayFontSize * 0.55
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                if let second = lines.second {
                    // Two whole lines: a fraction of a line more would show a sliver of the line above.
                    tail(Text(second.subtitleTail(300))
                        .font(.system(size: originalSize))
                        .foregroundStyle(.white.opacity(0.7)), lineHeight: Self.lineHeight(ofSystemFontSize: originalSize))
                        .frame(maxHeight: 2 * Self.lineHeight(ofSystemFontSize: originalSize))
                        .layoutPriority(2) // Keeps its two lines when the translation overflows.
                }
                tail(Text(lines.main.subtitleTail(400))
                    .font(.system(size: settings.overlayFontSize, weight: .semibold))
                    .foregroundStyle(.white), lineHeight: Self.lineHeight(ofSystemFontSize: settings.overlayFontSize))
                    .layoutPriority(1)
            }
        }
    }

    private var placeholder: String {
        if !model.translator.error.isEmpty {
            return model.translator.error
        }
        return model.capturing ? String(localized: "Listening… (\(model.translator.status.label))") : String(localized: "Subtitles appear here")
    }

    /// The non-scrollable ScrollView gives the text unlimited height but clips it, to a whole number of lines so no part-line shows at the top (a fade there covered the newest line when only about one line fit).
    private func tail(_ text: some View, lineHeight: CGFloat) -> some View {
        let centered = text.multilineTextAlignment(.center).frame(maxWidth: .infinity)
        return ViewThatFits(in: .vertical) {
            centered.fixedSize(horizontal: false, vertical: true)
            GeometryReader { proxy in
                let lines = max(1, (proxy.size.height / lineHeight).rounded(.down))
                ScrollView {
                    centered
                }
                .scrollDisabled(true)
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .frame(height: min(proxy.size.height, lines * lineHeight))
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    static func lineHeight(ofSystemFontSize size: CGFloat) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: size))
    }
}

private struct OverlayButtons: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(0.35))
                .allowsHitTesting(false)
            Button { Task { await model.toggleListening() } } label: {
                Image(systemName: model.capturing ? "stop.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.22), in: .circle)
            }
            .accessibilityLabel(model.capturing ? "Stop listening" : "Start listening")
            Button { settings.overlayVisible = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.2), in: .circle)
            }
            .accessibilityLabel("Hide subtitle overlay")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .pointerStyle(.default)
    }
}
