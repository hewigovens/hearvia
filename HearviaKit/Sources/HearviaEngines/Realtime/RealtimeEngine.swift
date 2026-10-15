import Foundation
import HearviaCore

/// gpt-realtime-translate over WebSocket. Translated audio is discarded.
/// The socket reconnects with backoff, closes during long silences (billing is per connected minute) and is
/// replaced before the session's 60-minute expiry.
@MainActor
public final class RealtimeEngine: TranslationEngine {
    typealias SocketFactory = @MainActor (RealtimeConfiguration) -> any RealtimeSocket

    public let updates: AsyncStream<EngineUpdate>
    let continuation: AsyncStream<EngineUpdate>.Continuation
    let timing: RealtimeTiming
    let transcribesSource: Bool
    private let makeSocket: SocketFactory
    var targetLanguage: String
    var running = false

    /// Where audio goes; nil while paused or waiting to reconnect.
    var socket: (any RealtimeSocket)?
    /// Set once `socket` has connected; until then audio collects in `backlog`.
    var socketReady = false
    /// The previous socket after a pause or rotation, still delivering its last text until it closes.
    var retiring: (any RealtimeSocket)?
    var paused = false
    var backlog: [Data] = []
    var silentChunks = 0
    var expiresAt: Date?
    var pump: Task<Void, Never>?
    var reconnectTask: Task<Void, Never>?

    /// All reconnects, for the status line and stats.
    var reconnects = 0
    /// Consecutive failed connections, for backoff and giving up; reset when a session starts.
    var failures = 0
    var chunksReceived = 0
    var chunksSent = 0
    var deltas = 0
    var lastProblem = ""
    var source = ""
    var translation = ""
    var segmenter = SentenceSegmenter()

    /// `transcribesSource: false` skips the original-language text, which is billed separately.
    public convenience init(targetLanguage: String, apiKey: String, transcribesSource: Bool = true) {
        self.init(targetLanguage: targetLanguage, transcribesSource: transcribesSource, timing: RealtimeTiming()) {
            RealtimeTranslationClient(configuration: $0, credential: apiKey)
        }
    }

    init(targetLanguage: String, transcribesSource: Bool, timing: RealtimeTiming, makeSocket: @escaping SocketFactory) {
        self.targetLanguage = targetLanguage
        self.transcribesSource = transcribesSource
        self.timing = timing
        self.makeSocket = makeSocket
        (updates, continuation) = AsyncStream.makeStream()
    }

    var configuration: RealtimeConfiguration {
        RealtimeConfiguration(targetLanguage: targetLanguage,
                              sourceTranscriptionModel: transcribesSource ? RealtimeConfiguration.defaultTranscriptionModel : nil)
    }

    public func start(audio: AsyncStream<Data>) async {
        guard !running else { return }
        running = true
        pump = Task { [weak self] in
            for await chunk in audio {
                await self?.consume(chunk)
            }
        }
        await connect()
    }

    public func setTargetLanguage(_ language: String) async -> Bool {
        targetLanguage = language
        try? await socket?.setTargetLanguage(language)
        return true
    }

    public func stop() async {
        guard running else { return }
        running = false
        pump?.cancel()
        pump = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        continuation.finish()
        if let retiring {
            self.retiring = nil
            Task { await retiring.cancel() }
        }
        guard let socket else { return }
        self.socket = nil
        retire(socket)
    }

    /// Opens a new socket. `announce: false` keeps the status line quiet for a session rotation.
    func connect(announce: Bool = true) async {
        guard running, !paused else { return }
        if announce {
            continuation.yield(.status(.connecting(attempt: reconnects)))
        }
        let socket = makeSocket(configuration)
        self.socket = socket
        socketReady = false
        expiresAt = nil
        Task { [weak self] in
            for await event in socket.events {
                self?.handle(event, from: socket)
            }
        }
        do {
            try await socket.connect()
            guard socket === self.socket else { return }
            socketReady = true
            continuation.yield(.log("translation_connected", ["target": targetLanguage, "reconnects": "\(reconnects)"]))
        } catch {
            handle(.closed(reason: error.localizedDescription), from: socket)
        }
    }

    /// Closes `socket` gracefully, keeping its trailing text, and cancels it if the server doesn't close it in time.
    func retire(_ socket: any RealtimeSocket) {
        if let previous = retiring, previous !== socket {
            Task { await previous.cancel() }
        }
        retiring = socket
        let grace = timing.closeGrace
        Task {
            await socket.close()
            try? await Task.sleep(for: grace)
            await socket.cancel()
        }
    }
}
