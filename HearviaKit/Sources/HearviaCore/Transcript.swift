import Foundation

/// Finished sentences (original + translation), oldest first, capped to the newest `limit` lines.
public struct Transcript: Equatable, Sendable {
    public private(set) var lines: [TranscriptLine] = []
    let limit: Int

    public init(limit: Int = 300) {
        self.limit = limit
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }

    /// Plain text for sharing: original above translation, sentences separated by a blank line.
    public var text: String {
        lines.map { $0.source.isEmpty ? $0.translation : "\($0.source)\n\($0.translation)" }.joined(separator: "\n\n")
    }

    public mutating func append(source: String, translation: String) {
        let line = TranscriptLine(id: (lines.last?.id ?? 0) + 1, source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                  translation: translation.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !line.translation.isEmpty || !line.source.isEmpty else { return }
        lines.append(line)
        if lines.count > limit {
            lines.removeFirst(lines.count - limit)
        }
    }
}
