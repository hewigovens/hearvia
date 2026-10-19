/// A sentence is committed when the translation ends one; the original is cut at its own last sentence end, so the pairing is approximate.
public struct SentenceSegmenter: Sendable {
    static let sentenceEnds: Set<Character> = [".", "!", "?", "。", "！", "？", "…"]

    private var source = ""
    private var translation = ""

    public init() {}

    public mutating func appendSource(_ delta: String) {
        source += delta
    }

    public mutating func appendTranslation(_ delta: String) -> (source: String, translation: String)? {
        translation += delta
        guard let end = translation.lastIndex(where: Self.sentenceEnds.contains) else { return nil }
        let translated = String(translation[...end])
        translation = String(translation[translation.index(after: end)...])
        var spoken = source
        if let sourceEnd = source.lastIndex(where: Self.sentenceEnds.contains) {
            spoken = String(source[...sourceEnd])
            source = String(source[source.index(after: sourceEnd)...])
        } else {
            source = ""
        }
        return (spoken, translated)
    }
}
