import Foundation
import HearviaCore
import HearviaEngines
@testable import HearviaSession
import Testing

/// An engine the test drives by hand.
@MainActor
final class FakeEngine: TranslationEngine {
    let kind: EngineKind
    let request: EngineRequest
    let updates: AsyncStream<EngineUpdate>
    private let continuation: AsyncStream<EngineUpdate>.Continuation
    var appliesLanguageLive = true
    private(set) var started = false
    private(set) var stopped = false
    private(set) var liveTargets: [String] = []

    init(kind: EngineKind, request: EngineRequest) {
        self.kind = kind
        self.request = request
        (updates, continuation) = AsyncStream.makeStream()
    }

    func send(_ update: EngineUpdate) {
        continuation.yield(update)
    }

    func start(audio _: AsyncStream<Data>) async {
        started = true
    }

    func setTargetLanguage(_ language: String) async -> Bool {
        liveTargets.append(language)
        return appliesLanguageLive
    }

    func stop() async {
        stopped = true
        continuation.finish()
    }
}

final class MemorySecrets: SecretStore, @unchecked Sendable {
    var values: [String: String]
    init(_ values: [String: String]) {
        self.values = values
    }

    func read(account: String) -> String? {
        values[account]
    }

    func write(_ value: String, account: String) {
        values[account] = value
    }
}

@MainActor
final class Harness {
    var engines: [FakeEngine] = []
    let defaults: UserDefaults
    let secrets: MemorySecrets
    lazy var translator = LiveTranslator(defaults: defaults, secrets: secrets) { [unowned self] kind, request in
        let engine = FakeEngine(kind: kind, request: request)
        engines.append(engine)
        return engine
    }

    init(apiKey: String? = "sk-test", geminiKey: String? = nil) {
        let suite = "hearvia.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        secrets = MemorySecrets(["openai-api-key": apiKey, "gemini-api-key": geminiKey].compactMapValues { $0 })
    }

    /// Lets the translator's listener task apply what the engine sent.
    func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }
}

@MainActor
struct LiveTranslatorTests {
    @Test func realtimeNeedsAnAPIKey() async {
        let harness = Harness(apiKey: nil)
        let translator = harness.translator
        #expect(translator.engine == .onDevice) // no key → on-device by default
        await translator.setEngine(.realtime)
        await translator.start()
        #expect(!translator.isActive)
        #expect(translator.status == .needsAPIKey)
        #expect(harness.engines.isEmpty)
    }

    @Test func appliesEngineUpdates() async throws {
        let harness = Harness()
        let translator = harness.translator
        var changes = 0
        translator.onTextChange = { changes += 1 }
        await translator.start()
        let engine = try #require(harness.engines.first)
        #expect(engine.started && engine.kind == .realtime && engine.request.apiKey == "sk-test")

        engine.send(.problem("rate_limited: slow down"))
        engine.send(.status(.connecting(attempt: 2)))
        engine.send(.status(.translating(onDevice: false)))
        engine.send(.audioConsumed)
        engine.send(.text(source: "Bonjour.", translation: "Hello."))
        engine.send(.text(source: "Bonjour. Ça", translation: "Hello."))
        engine.send(.sentence(source: "Bonjour.", translation: "Hello."))
        await harness.settle()

        #expect(translator.status == .translating(onDevice: false))
        #expect(translator.error.isEmpty) // cleared once translating
        #expect(translator.source == "Bonjour. Ça" && translator.translation == "Hello.")
        #expect(translator.transcript.lines.map(\.translation) == ["Hello."])
        #expect(translator.stats.chunksSent == 1 && translator.stats.reconnects == 2)
        #expect(translator.stats.deltas == 1) // only translation changes count
        #expect(changes == 2)
    }

    @Test func failureEndsTheRun() async throws {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        let engine = try #require(harness.engines.first)
        engine.send(.failed("invalid_api_key: nope"))
        await harness.settle()
        #expect(!translator.isActive)
        #expect(translator.status == .failed)
        #expect(translator.error == "invalid_api_key: nope")
    }

    @Test func ignoresUpdatesFromAStoppedEngine() async throws {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        let old = try #require(harness.engines.first)
        await translator.setEngine(.onDevice) // restarts with a new engine
        #expect(old.stopped && harness.engines.count == 2)
        old.send(.text(source: "stale", translation: "stale"))
        await harness.settle()
        #expect(translator.translation.isEmpty)
        #expect(translator.isActive)
    }

    @Test func targetLanguageChangesLiveOrRestarts() async throws {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        let realtime = try #require(harness.engines.first)
        await translator.setTargetLanguage("ja")
        #expect(realtime.liveTargets == ["ja"] && harness.engines.count == 1)

        realtime.appliesLanguageLive = false
        await translator.setTargetLanguage("ko")
        #expect(realtime.stopped && harness.engines.count == 2)
        #expect(harness.engines[1].request.targetLanguage == "ko")
    }

    @Test func spokenLanguageRestartsOnlyTheOnDeviceEngine() async {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        await translator.setSourceLanguage("fr")
        #expect(harness.engines.count == 1) // Realtime detects the spoken language
        await translator.setEngine(.onDevice)
        await translator.setSourceLanguage("de")
        #expect(harness.engines.count == 3)
        #expect(harness.engines[2].request.sourceLanguage == "de")
    }

    @Test func persistsPreferences() async {
        let harness = Harness()
        await harness.translator.setTargetLanguage("ja")
        await harness.translator.setEngine(.onDevice)
        harness.translator.openAIKey = "sk-new"
        harness.translator.geminiKey = "AIza-new"
        let reloaded = LiveTranslator(defaults: harness.defaults, secrets: harness.secrets)
        #expect(reloaded.targetLanguage == "ja" && reloaded.engine == .onDevice)
        #expect(reloaded.openAIKey == "sk-new" && reloaded.geminiKey == "AIza-new")
    }

    @Test func eachCloudEngineUsesItsOwnKey() async throws {
        let harness = Harness(apiKey: "sk-test", geminiKey: nil)
        let translator = harness.translator
        await translator.setEngine(.gemini)
        await translator.start()
        #expect(translator.status == .needsAPIKey && harness.engines.isEmpty)

        translator.geminiKey = "AIza-test"
        await translator.start()
        let engine = try #require(harness.engines.first)
        #expect(engine.kind == .gemini && engine.request.apiKey == "AIza-test")
    }

    @Test func fallbackKeysFillInUnsavedKeys() {
        let harness = Harness(apiKey: nil)
        let translator = LiveTranslator(fallbackKeys: [.gemini: "AIza-dev"], defaults: harness.defaults, secrets: harness.secrets)
        #expect(translator.geminiKey == "AIza-dev" && translator.openAIKey.isEmpty)
    }

    @Test func stopStopsTheEngine() async throws {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        await translator.stop()
        #expect(try #require(harness.engines.first).stopped)
        #expect(translator.status == .stopped && !translator.isActive)
    }
}
