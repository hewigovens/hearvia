import Foundation
import HearviaCore
@testable import HearviaEngines
import Testing

/// A Realtime socket the test drives by hand.
final class FakeSocket: RealtimeSocket, @unchecked Sendable {
    let configuration: RealtimeConfiguration
    let events: AsyncStream<RealtimeEvent>
    private let continuation: AsyncStream<RealtimeEvent>.Continuation
    private let lock = NSLock()
    private let failsToConnect: Bool
    private var sent: [Data] = []
    private var isClosed = false

    init(configuration: RealtimeConfiguration, failsToConnect: Bool) {
        self.configuration = configuration
        self.failsToConnect = failsToConnect
        (events, continuation) = AsyncStream.makeStream()
    }

    var appended: [Data] {
        lock.withLock { sent }
    }

    var closed: Bool {
        lock.withLock { isClosed }
    }

    func send(_ event: RealtimeEvent) {
        continuation.yield(event)
    }

    func connect() async throws {
        if failsToConnect {
            throw URLError(.cannotConnectToHost)
        }
    }

    func append(_ chunk: Data) async throws {
        lock.withLock { sent.append(chunk) }
    }

    func setTargetLanguage(_: String) async throws {}

    func close() async {
        lock.withLock { isClosed = true }
    }

    func cancel() async {
        continuation.finish()
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_000_000)

    var now: Date {
        lock.withLock { date }
    }

    func advance(to newDate: Date) {
        lock.withLock { date = newDate }
    }
}

@MainActor
final class RealtimeHarness {
    let clock = TestClock()
    var sockets: [FakeSocket] = []
    var failsToConnect = false
    var updates: [EngineUpdate] = []
    let audio: AsyncStream<Data>
    private let input: AsyncStream<Data>.Continuation
    lazy var engine = makeEngine(transcribesSource: true)

    init() {
        (audio, input) = AsyncStream.makeStream()
    }

    func makeEngine(transcribesSource: Bool) -> RealtimeEngine {
        var timing = RealtimeTiming()
        timing.silenceChunks = 5
        timing.preRollChunks = 2
        timing.connectingChunks = 10
        timing.maxFailures = 3
        timing.closeGrace = .seconds(5)
        timing.backoff = { _ in .milliseconds(1) }
        timing.now = { [clock] in clock.now }
        let engine = RealtimeEngine(targetLanguage: "zh", transcribesSource: transcribesSource, timing: timing) { [unowned self] configuration in
            let socket = FakeSocket(configuration: configuration, failsToConnect: failsToConnect)
            sockets.append(socket)
            return socket
        }
        Task {
            for await update in engine.updates {
                updates.append(update)
            }
        }
        return engine
    }

    func start() async {
        await engine.start(audio: audio)
    }

    /// Sends one chunk and waits until the engine has taken it.
    func feed(_ chunk: Data) async throws {
        let before = engine.chunksReceived
        input.yield(chunk)
        try await eventually { self.engine.chunksReceived > before }
    }

    var statuses: [TranslatorStatus] {
        updates.compactMap {
            if case let .status(status) = $0 {
                status
            } else {
                nil
            }
        }
    }
}

/// A 2-sample PCM16 chunk tagged by `marker` so tests can tell chunks apart; 0 is silent.
func chunk(_ marker: Int16) -> Data {
    [marker, marker].withUnsafeBytes { Data($0) }
}

@MainActor
func eventually(_ condition: @MainActor () -> Bool) async throws {
    for _ in 0 ..< 400 where !condition() {
        try await Task.sleep(for: .milliseconds(2))
    }
    #expect(condition())
}

@MainActor
struct RealtimeEngineTests {
    let harness = RealtimeHarness()

    @Test func reconnectsWithBackoffThenGivesUp() async throws {
        harness.failsToConnect = true
        await harness.start()
        try await eventually { self.harness.updates.last == .failed("Lost the connection to OpenAI.") }
        #expect(harness.sockets.count == 4) // first try + maxFailures reconnects
        #expect(harness.statuses.filter {
            if case .reconnecting = $0 {
                true
            } else {
                false
            }
        }.count == 3)
    }

    @Test func fatalErrorStopsWithoutReconnecting() async throws {
        await harness.start()
        let socket = try #require(harness.sockets.first)
        socket.send(.serverError(type: "invalid_request_error", code: "invalid_api_key", message: "Incorrect API key"))
        socket.send(.closed(reason: nil))
        try await eventually { self.harness.updates.last == .failed("invalid_api_key: Incorrect API key") }
        #expect(harness.sockets.count == 1)
    }

    @Test func reconnectAfterADroppedSessionCountsAsAnAttempt() async throws {
        await harness.start()
        harness.sockets[0].send(.sessionCreated(id: "s1", expiresAt: nil))
        harness.sockets[0].send(.closed(reason: "network"))
        try await eventually { self.harness.sockets.count == 2 }
        try await eventually { self.harness.statuses.contains(.connecting(attempt: 1)) }
    }

    @Test func pausesOnSilenceAndResumesWithPreRoll() async throws {
        await harness.start()
        let first = try #require(harness.sockets.first)
        first.send(.sessionCreated(id: "s1", expiresAt: nil))
        try await eventually { self.harness.engine.socketReady }
        try await harness.feed(chunk(1000))
        for _ in 0 ..< 5 {
            try await harness.feed(chunk(0))
        }
        try await eventually { self.harness.statuses.last == .paused }
        #expect(first.closed)
        #expect(harness.sockets.count == 1)

        // Silence while paused costs nothing; only the last two chunks are kept as pre-roll.
        try await harness.feed(chunk(0))
        try await harness.feed(chunk(1))
        try await harness.feed(chunk(2))
        try await harness.feed(chunk(1001)) // sound returns
        try await eventually { self.harness.sockets.count == 2 && self.harness.engine.socketReady }
        try await harness.feed(chunk(1002))
        #expect(harness.sockets[1].appended == [chunk(2), chunk(1001), chunk(1002)])
        // A pause is not a reconnect.
        #expect(harness.statuses.filter { $0 == .connecting(attempt: 0) }.count == 2)
        #expect(!harness.statuses.contains {
            if case .reconnecting = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test func rotatesBeforeExpiryAtASilentMoment() async throws {
        await harness.start()
        let first = try #require(harness.sockets.first)
        let expiry = harness.clock.now.addingTimeInterval(3600)
        first.send(.sessionCreated(id: "s1", expiresAt: expiry))
        try await eventually { self.harness.engine.expiresAt == expiry && self.harness.engine.socketReady }

        harness.clock.advance(to: expiry.addingTimeInterval(-170)) // inside the 180 s lead
        try await harness.feed(chunk(1000))
        #expect(harness.sockets.count == 1) // still speaking
        try await harness.feed(chunk(0))
        try await harness.feed(chunk(0))
        try await eventually { self.harness.sockets.count == 2 }
        #expect(first.closed)

        // The retired socket still delivers the translation of its last words.
        first.send(.translationDelta("再见。", elapsedMs: nil))
        try await eventually { self.harness.updates.contains(.sentence(source: "", translation: "再见。")) }
        let connecting = harness.statuses.filter {
            if case .connecting = $0 {
                true
            } else {
                false
            }
        }
        #expect(connecting.count == 1) // rotation is silent in the status line
    }

    @Test func rotatesAtTheDeadlineEvenWhileSpeaking() async throws {
        await harness.start()
        let expiry = harness.clock.now.addingTimeInterval(3600)
        harness.sockets[0].send(.sessionCreated(id: "s1", expiresAt: expiry))
        try await eventually { self.harness.engine.expiresAt == expiry && self.harness.engine.socketReady }
        harness.clock.advance(to: expiry.addingTimeInterval(-30))
        try await harness.feed(chunk(1000))
        try await eventually { self.harness.sockets.count == 2 }
    }

    @Test func skipsSourceTranscriptionWhenAsked() async {
        let engine = harness.makeEngine(transcribesSource: false)
        await engine.start(audio: harness.audio)
        #expect(harness.sockets.last?.configuration.sourceTranscriptionModel == nil)
        await engine.stop()

        let transcribing = harness.makeEngine(transcribesSource: true)
        await transcribing.start(audio: AsyncStream { $0.finish() })
        #expect(harness.sockets.last?.configuration.sourceTranscriptionModel == RealtimeConfiguration.defaultTranscriptionModel)
    }

    @Test func measuresChunkPeaks() {
        #expect(RealtimeEngine.peak(of: chunk(-1200)) == 1200)
        #expect(RealtimeEngine.peak(of: Data()) == 0)
    }
}
