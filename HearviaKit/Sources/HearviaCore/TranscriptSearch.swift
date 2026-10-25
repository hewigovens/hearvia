import Foundation

public enum TranscriptSearch {
    /// Blank and whitespace-only queries are not a search.
    public static func needle(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Non-overlapping matches of `query` in `text`. Comparison matches `localizedStandardContains`: case and diacritics ignored, locale aware.
    public static func matchRanges(in text: String, query: String, locale: Locale = .current) -> [Range<String.Index>] {
        let needle = needle(query)
        guard !needle.isEmpty, !text.isEmpty else { return [] }
        var found: [Range<String.Index>] = []
        var start = text.startIndex
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        while start < text.endIndex, let range = text.range(of: needle, options: options, range: start ..< text.endIndex, locale: locale) {
            found.append(range)
            // A zero-length match would otherwise spin.
            if range.upperBound <= start {
                break
            }
            start = range.upperBound
        }
        return found
    }
}

public extension TranscriptLine {
    /// Empty queries match nothing here. A transcript treats an empty query as "show everything".
    func matches(_ query: String) -> Bool {
        let needle = TranscriptSearch.needle(query)
        guard !needle.isEmpty else { return false }
        return source.localizedStandardContains(needle) || translation.localizedStandardContains(needle)
    }
}

public extension Transcript {
    /// An empty query matches every session. Otherwise any original or translation line may contain it.
    func matches(_ query: String) -> Bool {
        TranscriptSearch.needle(query).isEmpty || lines.contains { $0.matches(query) }
    }
}
