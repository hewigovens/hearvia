import Speech

/// Auto's choice among candidate recognizers. Speech has no language identification, but a recognizer for the wrong language is clearly less confident (about 0.25–0.7 against 0.95 on test clips); only finished sentences carry confidence.
struct LanguageContest {
    typealias Candidate = (language: String, module: SpeechTranscriber)
    enum Decision {
        case pick(Int)
        case best
    }

    /// Every language Auto chooses from, for reopening.
    let languages: [String]
    private(set) var candidates: [Int: Candidate] = [:]
    private(set) var winner: Int?
    private var finals: [Int: [SpeechTranscriber.Result]] = [:]
    private var nextID = 0
    private var reason = "start"
    private var undecidedTicks = 0
    /// Ticks come every 3 s (see +Detection), so Auto settles on its best guess after about 12 s.
    private static let patience = 4
    /// While re-detecting, the language in use; an unclear contest keeps it.
    private var previous: Int?

    mutating func add(_ module: SpeechTranscriber, _ language: String) -> Int {
        defer { nextID += 1 }
        candidates[nextID] = (language, module)
        return nextID
    }

    /// A finished sentence while undecided.
    mutating func heard(_ result: SpeechTranscriber.Result, from id: Int) -> Decision? {
        guard !String(result.text.characters).trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        finals[id, default: []].append(result)
        return Self.isConfident(finals[id]!) ? .pick(id) : settled ? .best : nil
    }

    mutating func tick() -> Decision? {
        undecidedTicks += 1
        return settled ? .best : nil
    }

    mutating func remove(_ id: Int) -> Decision? {
        candidates[id] = nil
        finals[id] = nil
        return winner == nil && !finals.isEmpty && settled ? .best : nil
    }

    /// One clear leader once every candidate has finished a sentence, or the best after about 12 s.
    private var settled: Bool {
        guard candidates.keys.allSatisfy({ finals[$0] != nil }) else { return false }
        let scores = candidates.keys.map { Self.confidence(finals[$0] ?? []) }.sorted(by: >)
        return undecidedTicks >= Self.patience || scores.count < 2 || scores[0] - scores[1] >= 0.2
    }

    /// Keeps only the winner; returns it with its withheld sentences and a note for the log.
    mutating func decide(_ decision: Decision) -> (winner: Candidate, finals: [SpeechTranscriber.Result], note: String) {
        var best = candidates.keys.max { Self.confidence(finals[$0] ?? []) < Self.confidence(finals[$1] ?? []) }!
        if case let .pick(id) = decision {
            best = id
        } else if undecidedTicks >= Self.patience, let previous, candidates[previous] != nil {
            best = previous
        }
        let scores = candidates.keys.sorted().map { String(format: "%@ %.2f", candidates[$0]!.language, Self.confidence(finals[$0] ?? [])) }
        let entry = candidates[best]!
        let result = (entry, finals[best] ?? [], "\(reason): \(scores.joined(separator: ", "))")
        candidates = [best: entry]
        winner = best
        finals = [:]
        undecidedTicks = 0
        previous = nil
        return result
    }

    /// The winner was unsure of a sentence, so the language may have changed.
    mutating func reopen(after result: SpeechTranscriber.Result) {
        reason = String(format: "%@ unsure %.2f", winner.flatMap { candidates[$0]?.language } ?? "", Self.confidence([result]))
        previous = winner
        winner = nil
    }

    static func isUnsure(_ result: SpeechTranscriber.Result) -> Bool {
        result.text.characters.count >= 8 && confidence([result]) < 0.6
    }

    /// Very short text can fool a wrong recognizer.
    private static func isConfident(_ results: [SpeechTranscriber.Result]) -> Bool {
        results.reduce(0) { $0 + $1.text.characters.count } >= 8 && confidence(results) >= 0.85
    }

    private static func confidence(_ results: [SpeechTranscriber.Result]) -> Double {
        let scores = results.flatMap { $0.text.runs.compactMap(\.transcriptionConfidence) }
        return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }
}
