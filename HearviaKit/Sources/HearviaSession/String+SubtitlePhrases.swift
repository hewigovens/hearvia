import NaturalLanguage

extension String {
    /// A reading gap at a likely phrase boundary is less prescriptive than adding punctuation to speech.
    var spacedJapaneseSubtitle: String {
        let text = String(suffix(400))
        guard text.contains(/\p{Script=Hiragana}\p{Script=Han}/) else { return self }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.japanese)
        tokenizer.string = text

        var result = ""
        var start = text.startIndex
        tokenizer.enumerateTokens(in: start ..< text.endIndex) { range, _ in
            let boundary = range.lowerBound
            guard text.distance(from: start, to: boundary) >= 3,
                  text[boundary...].prefix(1).contains(/\p{Script=Han}/),
                  text[..<boundary].suffix(1).contains(/\p{Script=Hiragana}/)
            else { return true }
            result += text[start ..< boundary] + " "
            start = boundary
            return true
        }
        return result + text[start...]
    }
}
