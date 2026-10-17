import Foundation

public struct Transcript: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public let engine: EngineKind
    /// Empty when the engine detected the spoken language.
    public let sourceLanguage: String
    public let targetLanguage: String
    public private(set) var lines: [TranscriptLine] = []

    public init(id: UUID = UUID(), startedAt: Date = .now, engine: EngineKind = .onDevice, sourceLanguage: String = "",
                targetLanguage: String = "") {
        self.id = id
        self.startedAt = startedAt
        self.engine = engine
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }

    public mutating func append(source: String, translation: String, at time: Date = .now) {
        let line = TranscriptLine(id: (lines.last?.id ?? 0) + 1, source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                  translation: translation.trimmingCharacters(in: .whitespacesAndNewlines), time: time)
        guard !line.translation.isEmpty || !line.source.isEmpty else { return }
        lines.append(line)
    }

    public var title: String {
        startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    public var summary: String {
        let minutes = max(1, Int(((endedAt ?? lines.last?.time ?? startedAt).timeIntervalSince(startedAt) / 60).rounded()))
        return "\(minutes) min · \(LanguageName.pair(source: sourceLanguage, target: targetLanguage)) · \(engine.title)"
    }

    public var text: String {
        let body = lines.map { line in
            let time = "[\(line.time.formatted(date: .omitted, time: .standard))]"
            return line.source.isEmpty ? "\(time) \(line.translation)" : "\(time) \(line.source)\n\(line.translation)"
        }
        return (["Hearvia transcript · \(title)", summary] + body).joined(separator: "\n\n")
    }

    /// A file name without characters that file systems reject: "Hearvia 2026-10-16 10.55".
    public var fileName: String {
        let stamp = Date.VerbatimFormatStyle(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)).\(minute: .twoDigits)",
                                             timeZone: .current, calendar: Calendar(identifier: .gregorian))
        return "Hearvia \(startedAt.formatted(stamp))"
    }
}
