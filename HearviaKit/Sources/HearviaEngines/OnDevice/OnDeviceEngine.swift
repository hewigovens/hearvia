import Foundation
import HearviaCore
import Translation

/// Finished segments are translated once; the volatile tail is re-translated as it changes.
@MainActor
public final class OnDeviceEngine: TranslationEngine {
    typealias ModelLoader = @MainActor (_ progress: @escaping @Sendable (Double) -> Void) async throws -> OnDeviceModelSet

    public let updates: AsyncStream<EngineUpdate>
    let continuation: AsyncStream<EngineUpdate>.Continuation
    /// Empty on Auto until the speech input settles on a language; changes when the speaker does.
    private(set) var sourceLanguage: String
    let targetLanguage: String
    private let load: ModelLoader
    private var translator: (@Sendable (String) async throws -> Translate?)?
    var running = false
    var translate: Translate?
    var kick: AsyncStream<Void>.Continuation?
    private var speech: (any SpeechInput)?
    private var tasks: [Task<Void, Never>] = []
    var finalSource = ""
    var volatileSource = ""
    var finalTranslation = ""
    var volatileTranslation = ""
    var finalQueue: [String] = []
    var pendingVolatile: String?
    var translatesDrafts = true
    var translationProblem = ""

    public convenience init(sourceLanguage: String, targetLanguage: String) {
        self.init(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { progress in
            try await Self.loadModels(sourceLanguage, targetLanguage, progress: progress)
        }
    }

    private static func loadModels(_ source: String, _ target: String,
                                   progress: @escaping @Sendable (Double) -> Void) async throws -> OnDeviceModelSet {
        if source.isEmpty {
            return try await detecting(label: "auto") { try await translation(from: $0, to: target).translate }
        }
        let (translate, strategy) = try await translation(from: source, to: target)
        return try await OnDeviceModelSet(speech: OnDeviceSpeech(language: source, progress: progress), translate: translate, strategy: strategy)
    }

    /// None for the same language, ICU for Simplified → Traditional Chinese, otherwise Apple's translator; `strategy` is for logs.
    private static func translation(from source: String, to target: String) async throws -> (translate: Translate?, strategy: String) {
        guard source != target else { return (nil, "none") }
        if let conversion = OnDeviceModels.scriptConversion(from: source, to: target) {
            return (conversion, "Hans-Hant")
        }
        let translator = try await OnDeviceTextTranslator(source: source, target: target)
        return ({ try await translator.translate($0) }, translator.strategy)
    }

    public static func localModel(sourceLanguage: String, targetLanguage: String, server: LocalModelServer,
                                  model: String) -> OnDeviceEngine {
        OnDeviceEngine(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { progress in
            guard !model.isEmpty else { throw LocalModelError.noModel }
            guard !sourceLanguage.isEmpty else {
                return try await detecting(label: model) { server.translator(from: $0, to: targetLanguage, model: model) }
            }
            let speech = try await OnDeviceSpeech(language: sourceLanguage, progress: progress)
            return OnDeviceModelSet(speech: speech, translate: server.translator(from: sourceLanguage, to: targetLanguage, model: model), strategy: model)
        }
    }

    private static func detecting(label: String, translator: @escaping @Sendable (String) async throws -> Translate?) async throws -> OnDeviceModelSet {
        let candidates = await OnDeviceModels.autoCandidates()
        var models = try await OnDeviceModelSet(speech: OnDeviceSpeech.detecting(candidates), translate: nil,
                                                strategy: "\(label) \(candidates.joined(separator: ","))")
        models.translator = translator
        return models
    }

    init(sourceLanguage: String, targetLanguage: String, load: @escaping ModelLoader) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.load = load
        (updates, continuation) = AsyncStream.makeStream()
    }

    public func start(audio: AsyncStream<Data>) async {
        guard !running else { return }
        running = true
        continuation.yield(.status(.loadingModels))
        do {
            let models = try await load { [continuation] progress in
                continuation.yield(.status(.downloadingSpeech(percent: Int(progress * 100))))
            }
            guard running else {
                await models.speech.finish()
                return
            }
            listen(audio, with: models)
        } catch {
            fail(error)
        }
    }

    /// Restarting is the only way to change languages: the speech and translation models are per language.
    public func setTargetLanguage(_: String) async -> Bool {
        false
    }

    public func stop() async {
        guard running else { return }
        running = false
        let speech = shutDown()
        continuation.finish()
        await speech?.finish() // A restart needs the recognizers freed first.
    }

    private func listen(_ audio: AsyncStream<Data>, with models: OnDeviceModelSet) {
        let speech = models.speech
        self.speech = speech
        translate = models.translate
        translator = models.translator
        let (kicks, kick) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.kick = kick
        continuation.yield(.status(.translating(onDevice: true)))
        continuation.yield(.log("ondevice_started", ["source": sourceLanguage, "target": targetLanguage, "translation_model": models.strategy]))
        tasks = [
            Task { [weak self] in
                for await chunk in audio {
                    do {
                        try speech.append(chunk)
                        self?.continuation.yield(.audioConsumed)
                    } catch { self?.continuation.yield(.log("ondevice_audio_error", ["error": "\(error)"])) }
                }
            },
            Task { [weak self] in
                do {
                    for try await result in speech.results {
                        if !result.detection.isEmpty {
                            self?.continuation.yield(.log("ondevice_detection", ["result": result.detection]))
                        }
                        try await self?.adopt(result.language)
                        self?.handleSpeech(result)
                    }
                } catch { self?.fail(error) }
            },
            Task { [weak self] in
                for await _ in kicks {
                    await self?.drainTranslations()
                }
            }
        ]
    }

    private func adopt(_ language: String) async throws {
        guard !language.isEmpty, language != sourceLanguage, let translator else { return }
        sourceLanguage = language
        volatileSource = ""
        pendingVolatile = nil
        continuation.yield(.log("ondevice_language_detected", ["language": language]))
        translate = try await translator(language)
    }

    func fail(_ error: Error) {
        guard running else { return }
        running = false
        continuation.yield(.log("ondevice_error", ["error": "\(error)"]))
        if let speech = shutDown() {
            Task { await speech.finish() }
        }
        continuation.yield(.failed(error.localizedDescription))
        continuation.finish()
    }

    private func shutDown() -> (any SpeechInput)? {
        kick?.finish()
        kick = nil
        tasks.forEach { $0.cancel() }
        tasks = []
        translate = nil
        defer { speech = nil }
        return speech
    }
}
