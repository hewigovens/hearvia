import Foundation

extension LiveTranslator {
    public var transcriptText: String {
        transcript.map { $0.source.isEmpty ? $0.translation : "\($0.source)\n\($0.translation)" }.joined(separator: "\n\n")
    }

    func appendTranscript(source: String, translation: String) {
        let line = TranscriptLine(id: (transcript.last?.id ?? 0) + 1, source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                  translation: translation.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !line.translation.isEmpty || !line.source.isEmpty else { return }
        transcript.append(line)
        if transcript.count > 300 {
            transcript.removeFirst(transcript.count - 300)
        }
    }

    /// Realtime deltas are a continuous stream; cut a transcript line whenever the translation ends a sentence.
    /// The source is cut at its own last sentence end, so the pairing is approximate.
    func commitRealtimeSentences() {
        guard let end = pendingTranslation.lastIndex(where: Self.sentenceEnds.contains) else { return }
        let translated = String(pendingTranslation[...end])
        pendingTranslation = String(pendingTranslation[pendingTranslation.index(after: end)...])
        var spoken = pendingSource
        if let sourceEnd = pendingSource.lastIndex(where: Self.sentenceEnds.contains) {
            spoken = String(pendingSource[...sourceEnd])
            pendingSource = String(pendingSource[pendingSource.index(after: sourceEnd)...])
        } else {
            pendingSource = ""
        }
        appendTranscript(source: spoken, translation: translated)
    }

    static let sentenceEnds: Set<Character> = [".", "!", "?", "。", "！", "？", "…"]
}
