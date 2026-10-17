import Foundation
import HearviaCore
import Observation

/// Past transcripts, newest first, one JSON file each: in Application Support/Hearvia/Transcripts, or in the app's
/// iCloud container while `syncsWithICloud` is on (see TranscriptHistory+iCloud).
@MainActor @Observable
public final class TranscriptHistory {
    public internal(set) var transcripts: [Transcript] = []
    /// Keeps transcripts in iCloud so they appear on the user's other devices. Off by default.
    public var syncsWithICloud: Bool {
        didSet {
            guard syncsWithICloud != oldValue else { return }
            UserDefaults.standard.set(syncsWithICloud, forKey: Keys.syncsWithICloud)
            if syncsWithICloud {
                Task { await startSync() }
            } else {
                stopSync()
            }
        }
    }
    /// True once transcripts live in iCloud; false when sync is off or iCloud isn't available.
    public internal(set) var isInICloud = false

    @ObservationIgnored let localDirectory: URL
    @ObservationIgnored var directory: URL
    @ObservationIgnored let cloudContainer: String?
    @ObservationIgnored var query: NSMetadataQuery?
    @ObservationIgnored var observers: [NSObjectProtocol] = []

    public static var defaultDirectory: URL {
        // Unsandboxed Mac builds share Application Support with every app, hence the Hearvia folder.
        URL.applicationSupportDirectory.appending(path: "Hearvia/Transcripts", directoryHint: .isDirectory)
    }

    /// `cloudContainer` nil turns iCloud off entirely (tests).
    public init(directory: URL = TranscriptHistory.defaultDirectory, cloudContainer: String? = "iCloud.dev.hewig.hearvia") {
        localDirectory = directory
        self.directory = directory
        self.cloudContainer = cloudContainer
        syncsWithICloud = cloudContainer != nil && UserDefaults.standard.bool(forKey: Keys.syncsWithICloud)
        transcripts = Self.read(directory)
        if syncsWithICloud {
            Task { await startSync() }
        }
    }

    /// Adds or replaces `transcript`; an empty one isn't kept.
    public func save(_ transcript: Transcript) {
        guard !transcript.isEmpty else { return }
        transcripts.removeAll { $0.id == transcript.id }
        transcripts.insert(transcript, at: transcripts.firstIndex { $0.startedAt < transcript.startedAt } ?? transcripts.endIndex)
        Self.write(transcript, to: file(transcript.id))
    }

    public func delete(_ transcript: Transcript) {
        transcripts.removeAll { $0.id == transcript.id }
        Self.remove(file(transcript.id))
    }

    public func deleteAll() {
        transcripts.forEach(delete)
    }

    func file(_ id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    /// Newest first; unreadable files (or iCloud placeholders not downloaded yet) are skipped.
    nonisolated static func read(_ folder: URL) -> [Transcript] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return read(files: files.filter { $0.pathExtension == "json" })
    }

    nonisolated static func read(files: [URL]) -> [Transcript] {
        files.compactMap { url in
            var data: Data?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: nil) { data = try? Data(contentsOf: $0) }
            return data.flatMap { try? JSONDecoder().decode(Transcript.self, from: $0) }
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    /// Coordinated, so iCloud never uploads a half-written file. Default protection: saves also happen while the
    /// iPhone is locked.
    static func write(_ transcript: Transcript, to url: URL) {
        guard let data = try? JSONEncoder().encode(transcript) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: nil) { try? data.write(to: $0, options: .atomic) }
    }

    static func remove(_ url: URL) {
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: nil) { try? FileManager.default.removeItem(at: $0) }
    }

    enum Keys {
        static let syncsWithICloud = "hearvia.syncsTranscriptsWithICloud"
    }
}
