import HearviaCore
import SwiftUI

public struct TranscriptList: View {
    let lines: [TranscriptLine]
    let originalFont: Font
    let translationFont: Font

    public init(lines: [TranscriptLine], originalFont: Font = .footnote, translationFont: Font = .callout) {
        self.lines = lines
        self.originalFont = originalFont
        self.translationFont = translationFont
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
                                Text(line.source).font(originalFont).foregroundStyle(Color.hvMuted)
                            }
                            Text(line.translation).font(translationFont)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(line.id)
                    }
                }
                .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)
            .onChange(of: lines.last?.id) { _, id in
                if let id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }
}
