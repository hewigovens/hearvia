import HearviaCore
import SwiftUI

public struct TranscriptList: View {
    let lines: [TranscriptLine]
    let originalFont: Font
    let translationFont: Font
    let query: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(lines: [TranscriptLine], originalFont: Font = .footnote, translationFont: Font = .callout, query: String = "") {
        self.lines = lines
        self.originalFont = originalFont
        self.translationFont = translationFont
        self.query = query
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if lines.isEmpty {
                        Text("Finished sentences collect here, with the original above each translation.")
                            .font(originalFont)
                            .foregroundStyle(Color.hvMuted)
                    }
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            if !line.source.isEmpty {
                                Text(marked(line.source, base: .hvMuted)).font(originalFont)
                            }
                            Text(marked(line.translation, base: .hvText)).font(translationFont)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(line.id)
                    }
                }
                .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                if firstMatchID != nil {
                    place(proxy, animated: true)
                } else if let id = lines.last?.id {
                    scroll(proxy, to: id, anchor: .bottom, animated: false)
                }
            }
            .onChange(of: lines.last?.id) { _, id in
                guard TranscriptSearch.needle(query).isEmpty, let id else { return }
                scroll(proxy, to: id, anchor: .bottom, animated: true)
            }
            .onChange(of: query) { old, new in
                guard TranscriptSearch.needle(old) != TranscriptSearch.needle(new), firstMatchID != nil else { return }
                place(proxy, animated: true)
            }
        }
    }

    private var firstMatchID: Int? {
        lines.first { $0.matches(query) }?.id
    }

    /// One string per line, so VoiceOver reads the sentence once. A match is a solid highlight, not a separate control.
    private func marked(_ text: String, base: Color) -> AttributedString {
        var attributed = AttributedString(text)
        var plain = AttributeContainer()
        plain.foregroundColor = base
        attributed.setAttributes(plain)
        var mark = AttributeContainer()
        mark.foregroundColor = Color.hvText
        mark.backgroundColor = Color.hvSelected
        for range in TranscriptSearch.matchRanges(in: text, query: query) {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].setAttributes(mark)
        }
        return attributed
    }

    private func place(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let id = firstMatchID else { return }
        scroll(proxy, to: id, anchor: .center, animated: animated)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: Int, anchor: UnitPoint, animated: Bool) {
        if animated, !reduceMotion {
            withAnimation { proxy.scrollTo(id, anchor: anchor) }
        } else {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}
