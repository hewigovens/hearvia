import Foundation
import HearviaAudio
import HearviaCore
import HearviaEngines
import Observation

@MainActor @Observable
public final class LiveTranslator {
    public typealias EngineFactory = @MainActor (_ kind: EngineKind, _ request: EngineRequest) -> any TranslationEngine

    public private(set) var engine: EngineKind {
        didSet { defaults.set(engine.rawValue, forKey: Keys.engine) }
    }
    /// Spoken language; only the on-device engine uses it (the cloud engines detect it).
    public private(set) var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }
    public private(set) var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }
    public var openAIKey: String {
        didSet { secrets.write(openAIKey, account: EngineKind.realtime.keyAccount!) }
    }
    public var geminiKey: String {
        didSet { secrets.write(geminiKey, account: EngineKind.gemini.keyAccount!) }
    }
    public var localServerURL: String {
        didSet { defaults.set(localServerURL, forKey: Keys.localServerURL) }
    }
    public var localKey: String {
        didSet { secrets.write(localKey, account: EngineKind.local.keyAccount!) }
    }
    public var localModel: String {
        didSet { defaults.set(localModel, forKey: Keys.localModel) }
    }
    public var localServer: LocalModelServer {
        LocalModelServer(baseURL: localServerURL, apiKey: localKey)
    }
    public var apiKey: String {
        switch engine {
        case .onDevice, .local: ""
        case .realtime: openAIKey
        case .gemini: geminiKey
        }
    }
    /// Whether a cloud engine also returns the original-language text, which OpenAI bills separately. The apps follow their "show original speech" setting. Not persisted.
    public private(set) var transcribesSource = true

    public internal(set) var isActive = false
    public internal(set) var status = TranslatorStatus.idle
    public internal(set) var error = ""
    public internal(set) var source = ""
    public internal(set) var translation = ""
    public internal(set) var transcript = Transcript()
    public internal(set) var stats = TranslatorStats()
    public let history: TranscriptHistory
    public var savesTranscripts: Bool {
        didSet { defaults.set(savesTranscripts, forKey: Keys.savesTranscripts) }
    }

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

    /// `fallbackKeys` stand in for keys not saved yet (Debug builds pass the ones from `.env`).
    public init(fallbackKeys: [EngineKind: String] = [:], defaults: UserDefaults = .standard, secrets: any SecretStore = KeychainStore(),
                history: TranscriptHistory = TranscriptHistory(), makeEngine: @escaping EngineFactory = LiveTranslator.makeEngine) {
        self.defaults = defaults
        self.secrets = secrets
        self.history = history
        self.makeEngine = makeEngine
        savesTranscripts = defaults.object(forKey: Keys.savesTranscripts) as? Bool ?? true
        func key(_ engine: EngineKind) -> String {
            secrets.read(account: engine.keyAccount!) ?? fallbackKeys[engine] ?? ""
        }
        let openAIKey = key(.realtime)
        self.openAIKey = openAIKey
        geminiKey = key(.gemini)
        localKey = secrets.read(account: EngineKind.local.keyAccount!) ?? ""
        localServerURL = defaults.string(forKey: Keys.localServerURL) ?? LocalModelServer.presets[0].baseURL
        localModel = defaults.string(forKey: Keys.localModel) ?? ""
        engine = defaults.string(forKey: Keys.engine).flatMap(EngineKind.init) ?? (openAIKey.isEmpty ? .onDevice : .realtime)
        sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "zh"
    }

    public static func makeEngine(_ kind: EngineKind, _ request: EngineRequest) -> any TranslationEngine {
        switch kind {
        case .realtime: CloudEngine.openAI(targetLanguage: request.targetLanguage, apiKey: request.apiKey,
                                           transcribesSource: request.transcribesSource)
        case .gemini: CloudEngine.gemini(targetLanguage: request.targetLanguage, apiKey: request.apiKey,
                                         transcribesSource: request.transcribesSource)
        case .onDevice: OnDeviceEngine(sourceLanguage: request.sourceLanguage, targetLanguage: request.targetLanguage)
        case .local: OnDeviceEngine.localModel(sourceLanguage: request.sourceLanguage, targetLanguage: request.targetLanguage,
                                               server: request.localServer, model: request.localModel)
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
        if engine.isCloud {
            targetLanguage = Languages.target(targetLanguage, for: engine) // On-device offers more languages.
        }
        await restartIfActive()
    }

    /// Restarts a running cloud engine so the change applies right away: turning the original on should show it now, and turning it off should stop paying for it now. The on-device engine always has the original.
    public func setTranscribesSource(_ transcribes: Bool) async {
        guard transcribes != transcribesSource else { return }
        transcribesSource = transcribes
        if engine.isCloud {
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
        static let savesTranscripts = "hearvia.savesTranscripts"
        static let localServerURL = "hearvia.localServerURL"
        static let localModel = "hearvia.localModel"
    }
}

public struct EngineRequest: Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String
    public let apiKey: String
    public let transcribesSource: Bool
    public var localServer = LocalModelServer(baseURL: "")
    public var localModel = ""
}
