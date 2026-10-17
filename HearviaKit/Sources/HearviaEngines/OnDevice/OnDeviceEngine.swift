import Foundation
import HearviaCore
import Translation

/// SpeechTranscriber → Translation framework, entirely on this device.
/// Finished segments are translated once; the volatile tail is re-translated as it changes.
@MainActor
public final class OnDeviceEngine: TranslationEngine {
    typealias ModelLoader = @MainActor (_ progress: @escaping @Sendable (Double) -> Void) async throws -> OnDeviceModelSet

    public let updates: AsyncStream<EngineUpdate>
    let continuation: AsyncStream<EngineUpdate>.Continuation
    let sourceLanguage: String
    let targetLanguage: String
    private let load: ModelLoader
    var running = false
    var translate: (@Sendable (String) async throws -> String)?
    var kick: AsyncStream<Void>.Continuation?
    private var speech: (any SpeechInput)?
    private var tasks: [Task<Void, Never>] = []
    var finalSource = ""
    var volatileSource = ""
    var finalTranslation = ""
    var volatileTranslation = ""
    var finalQueue: [String] = []
    var pendingVolatile: String?
    /// The translation error on screen, cleared by the next translation that works.
    var translationProblem = ""

    public convenience init(sourceLanguage: String, targetLanguage: String) {
        self.init(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { progress in
            try await Self.loadModels(sourceLanguage, targetLanguage, progress: progress)
        }
    }

    private static func loadModels(_ source: String, _ target: String,
                                   progress: @escaping @Sendable (Double) -> Void) async throws -> OnDeviceModelSet {
        guard source != target else {
            return try await OnDeviceModelSet(speech: OnDeviceSpeech(language: source, progress: progress), translate: nil, strategy: "none")
        }
        let translator = try await OnDeviceTextTranslator(source: source, target: target)
        let speech = try await OnDeviceSpeech(language: source, progress: progress)
        let translate: @Sendable (String) async throws -> String = { try await translator.translate($0) }
        return OnDeviceModelSet(speech: speech, translate: translate, strategy: translator.strategy)
    }

    /// Apple speech recognition with each sentence translated by a model on the user's own server.
    public static func localModel(sourceLanguage: String, targetLanguage: String, server: LocalModelServer,
                                  model: String) -> OnDeviceEngine {
        OnDeviceEngine(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) { progress in
            guard !model.isEmpty else { throw LocalModelError.noModel }
            let speech = try await OnDeviceSpeech(language: sourceLanguage, progress: progress)
            let translate: @Sendable (String) async throws -> String = {
                try await server.translate($0, from: sourceLanguage, to: targetLanguage, model: model)
            }
            return OnDeviceModelSet(speech: speech, translate: sourceLanguage == targetLanguage ? nil : translate, strategy: model)
        }
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
        shutDown()
        continuation.finish()
    }

    private func listen(_ audio: AsyncStream<Data>, with models: OnDeviceModelSet) {
        let speech = models.speech
        self.speech = speech
        translate = models.translate
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

    func fail(_ error: Error) {
        guard running else { return }
        running = false
        continuation.yield(.log("ondevice_error", ["error": "\(error)"]))
        shutDown()
        continuation.yield(.failed(error.localizedDescription))
        continuation.finish()
    }

    private func shutDown() {
        kick?.finish()
        kick = nil
        tasks.forEach { $0.cancel() }
        tasks = []
        translate = nil
        if let speech {
            self.speech = nil
            Task { await speech.finish() }
        }
    }
}
