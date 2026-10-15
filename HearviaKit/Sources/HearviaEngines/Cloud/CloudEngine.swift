import Foundation
import HearviaCore

/// A streaming cloud translator (OpenAI Realtime or Gemini Live) over a `TranslationSocket`. Translated audio is
/// discarded. The socket reconnects with backoff, closes during long silences (both providers bill for streamed
/// time) and is replaced before the provider ends the connection.
@MainActor
public final class CloudEngine: TranslationEngine {
    typealias SocketFactory = @MainActor (_ targetLanguage: String, _ transcribesSource: Bool) -> any TranslationSocket

    public let updates: AsyncStream<EngineUpdate>
    let continuation: AsyncStream<EngineUpdate>.Continuation
    /// "OpenAI" or "Gemini", for messages.
    let provider: String
    let timing: CloudTiming
    let transcribesSource: Bool
    private let makeSocket: SocketFactory
    var targetLanguage: String
    var running = false

    /// Where audio goes; nil while paused or waiting to reconnect.
    var socket: (any TranslationSocket)?
    /// Set once `socket` has connected; until then audio collects in `backlog`.
    var socketReady = false
    /// The previous socket after a pause or rotation, still delivering its last text until it closes.
    var retiring: (any TranslationSocket)?
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
    /// The server rejected the key or the account; reconnecting would fail the same way.
    var fatalProblem = false
    var source = ""
    var translation = ""
    var segmenter = SentenceSegmenter()

    /// gpt-realtime-translate. `transcribesSource: false` skips the original-language text, which is billed separately.
    public static func openAI(targetLanguage: String, apiKey: String, transcribesSource: Bool = true) -> CloudEngine {
        CloudEngine(provider: "OpenAI", targetLanguage: targetLanguage, transcribesSource: transcribesSource, timing: CloudTiming()) {
            OpenAIRealtimeClient(configuration: OpenAIRealtimeConfiguration(targetLanguage: $0, transcribesSource: $1), credential: apiKey)
        }
    }

    /// gemini-3.5-live-translate over the Live API.
    public static func gemini(targetLanguage: String, apiKey: String, transcribesSource: Bool = true) -> CloudEngine {
        CloudEngine(provider: "Gemini", targetLanguage: targetLanguage, transcribesSource: transcribesSource, timing: CloudTiming()) {
            GeminiLiveClient(configuration: GeminiLiveConfiguration(targetLanguage: $0, transcribesSource: $1), apiKey: apiKey)
        }
    }

    init(provider: String, targetLanguage: String, transcribesSource: Bool, timing: CloudTiming, makeSocket: @escaping SocketFactory) {
        self.provider = provider
        self.targetLanguage = targetLanguage
        self.transcribesSource = transcribesSource
        self.timing = timing
        self.makeSocket = makeSocket
        (updates, continuation) = AsyncStream.makeStream()
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
        guard let socket, await (try? socket.setTargetLanguage(language)) != true else { return true }
        rotate(reason: "language")
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
        let socket = makeSocket(targetLanguage, transcribesSource)
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
            continuation.yield(.log("translation_connected", ["provider": provider, "target": targetLanguage, "reconnects": "\(reconnects)"]))
        } catch {
            handle(.closed(reason: error.localizedDescription), from: socket)
        }
    }

    /// Replaces the socket with a fresh session; the old one keeps delivering its last words.
    func rotate(reason: String) {
        guard let socket else { return }
        let left = expiresAt.map { Int($0.timeIntervalSince(timing.now())) }
        self.socket = nil
        socketReady = false
        expiresAt = nil
        retire(socket)
        continuation.yield(.log("translation_rotated", ["reason": reason, "seconds_left": left.map(String.init) ?? ""]))
        Task { await connect(announce: false) }
    }

    /// Closes `socket` gracefully, keeping its trailing text, and cancels it if the server doesn't close it in time.
    func retire(_ socket: any TranslationSocket) {
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
