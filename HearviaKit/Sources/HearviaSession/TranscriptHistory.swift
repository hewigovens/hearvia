import Foundation
import HearviaCore
import Observation

/// Past transcripts, newest first, one JSON file each in Application Support/Hearvia/Transcripts. Kept on this device only.
@MainActor @Observable
public final class TranscriptHistory {
    public private(set) var transcripts: [Transcript] = []
    @ObservationIgnored private let directory: URL

    public static var defaultDirectory: URL {
        // Unsandboxed Mac builds share Application Support with every app, hence the Hearvia folder.
        URL.applicationSupportDirectory.appending(path: "Hearvia/Transcripts", directoryHint: .isDirectory)
    }

    public init(directory: URL = TranscriptHistory.defaultDirectory) {
        self.directory = directory
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        transcripts = files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Transcript.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Adds or replaces `transcript`; an empty one isn't kept.
    public func save(_ transcript: Transcript) {
        guard !transcript.isEmpty else { return }
        transcripts.removeAll { $0.id == transcript.id }
        transcripts.insert(transcript, at: transcripts.firstIndex { $0.startedAt < transcript.startedAt } ?? transcripts.endIndex)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(transcript).write(to: file(transcript.id), options: .atomic) // Default protection: saves also happen while the iPhone is locked.
    }

    public func delete(_ transcript: Transcript) {
        transcripts.removeAll { $0.id == transcript.id }
        try? FileManager.default.removeItem(at: file(transcript.id))
    }

    public func deleteAll() {
        transcripts.forEach(delete)
    }

    private func file(_ id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
