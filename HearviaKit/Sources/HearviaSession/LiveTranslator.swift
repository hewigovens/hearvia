import Foundation
import HearviaAudio
import HearviaCore
import HearviaEngines
import Observation

/// The live subtitle pipeline both apps share: captured PCM → `feed` → engine → observable text and transcript.
/// Owns the translation preferences (languages, engine, API key) and one engine run at a time.
@MainActor @Observable
public final class LiveTranslator {
    public typealias EngineFactory = @MainActor (_ kind: EngineKind, _ request: EngineRequest) -> any TranslationEngine

    public private(set) var engine: EngineKind {
        didSet { defaults.set(engine.rawValue, forKey: Keys.engine) }
    }
    /// Spoken language; only the on-device engine uses it (Realtime detects it).
    public private(set) var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }
    public private(set) var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    public var apiKey: String {
        didSet { secrets.write(apiKey) }
    }
    /// Whether the Realtime engine also returns the original-language text, which is billed separately.
    /// The apps follow their "show original speech" setting. Not persisted.
    public private(set) var transcribesSource = true

    public internal(set) var isActive = false
    public internal(set) var status = TranslatorStatus.idle
    public internal(set) var error = ""
    public internal(set) var source = ""
    public internal(set) var translation = ""
    public internal(set) var transcript = Transcript()
    public internal(set) var stats = TranslatorStats()

    /// Called on every text change, for consumers that draw outside SwiftUI (the PiP renderer, logs).
    public var onTextChange: (() -> Void)?
    public var onLog: ((String, [String: String]) -> Void)?
    /// Push captured PCM here from any single serial queue.
    public nonisolated let feed = AudioFeed()

    @ObservationIgnored var running: (any TranslationEngine)?
    @ObservationIgnored var listener: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: any SecretStore
    @ObservationIgnored let makeEngine: EngineFactory

    public init(fallbackKey: String = "", defaults: UserDefaults = .standard, secrets: any SecretStore = KeychainStore(),
                makeEngine: @escaping EngineFactory = LiveTranslator.makeEngine) {
        self.defaults = defaults
        self.secrets = secrets
        self.makeEngine = makeEngine
        let key = secrets.read() ?? fallbackKey
        apiKey = key
        engine = defaults.string(forKey: Keys.engine).flatMap(EngineKind.init) ?? (key.isEmpty ? .onDevice : .realtime)
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "zh"
    }

    public static func makeEngine(_ kind: EngineKind, _ request: EngineRequest) -> any TranslationEngine {
        switch kind {
        case .realtime: RealtimeEngine(targetLanguage: request.targetLanguage, apiKey: request.apiKey,
                                       transcribesSource: request.transcribesSource)
        case .onDevice: OnDeviceEngine(sourceLanguage: request.sourceLanguage, targetLanguage: request.targetLanguage)
        }
    }

    public func setTargetLanguage(_ language: String) async {
        guard language != targetLanguage else { return }
        targetLanguage = language
        guard let running else { return }
        if await !running.setTargetLanguage(language) {
            await restartIfActive()
        }
    }

    public func setSourceLanguage(_ language: String) async {
        guard language != sourceLanguage else { return }
        sourceLanguage = language
        if !engine.detectsSpokenLanguage {
            await restartIfActive()
        }
    }

    public func setEngine(_ engine: EngineKind) async {
        guard engine != self.engine else { return }
        self.engine = engine
        if engine == .realtime {
            targetLanguage = Languages.realtimeTarget(for: targetLanguage) // On-device offers more languages.
        }
        await restartIfActive()
    }

    /// Restarts a running Realtime engine so the change applies right away: turning the original on should show it
    /// now, and turning it off should stop paying for it now. The on-device engine always has the original.
    public func setTranscribesSource(_ transcribes: Bool) async {
        guard transcribes != transcribesSource else { return }
        transcribesSource = transcribes
        if engine == .realtime {
            await restartIfActive()
        }
    }

    private func restartIfActive() async {
        guard isActive else { return }
        await stop()
        await start()
    }

    enum Keys {
        static let engine = "hearvia.engine"
        static let sourceLanguage = "hearvia.sourceLanguage"
        static let targetLanguage = "hearvia.targetLanguage"
    }
}

/// What an engine needs to start one run.
public struct EngineRequest: Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String
    public let apiKey: String
    public let transcribesSource: Bool
}
