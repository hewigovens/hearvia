import AVFoundation
import Speech
import Translation

/// Which pipeline turns captured audio into subtitles.
public enum TranslationEngine: String, CaseIterable, Identifiable, Sendable {
    /// SpeechTranscriber + Translation framework: free, offline, sentence-level lag.
    case onDevice
    /// gpt-realtime-translate over WebSocket: lowest lag, paid per minute.
    case realtime

    public var id: String { rawValue }
    public var title: String { self == .realtime ? "OpenAI Realtime" : "On-device" }
    public var summary: String {
        self == .realtime ? "Fastest, best quality. Uses OpenAI credit (~$2/hour)."
                          : "Free and private. Runs on this device; a little behind the speaker."
    }
}

public enum OnDeviceError: LocalizedError {
    case speechUnsupported(String)
    case translationUnsupported(String, String)
    case translationNotInstalled(String, String)

    public var errorDescription: String? {
        switch self {
        case .speechUnsupported(let l): "On-device speech recognition doesn't support \(LanguageLabel.of(l))."
        case .translationUnsupported(let s, let t): "On-device translation from \(LanguageLabel.of(s)) to \(LanguageLabel.of(t)) isn't supported."
        case .translationNotInstalled(let s, let t): "Download the \(LanguageLabel.of(s)) → \(LanguageLabel.of(t)) translation language first."
        }
    }
}

/// Model availability for the on-device engine, keyed by the app's two-letter language codes.
public enum OnDeviceModels {
    public enum Availability: Sendable, Equatable {
        case unsupported, downloadable, downloading, installed
        public var label: String {
            switch self {
            case .unsupported: "Not supported"
            case .downloadable: "Needs download"
            case .downloading: "Downloading…"
            case .installed: "Ready"
            }
        }
    }

    /// The speech model needs a region; these are the most common variants.
    static func speechLocale(_ code: String) -> Locale {
        let map = ["zh": "zh-CN", "en": "en-US", "ja": "ja-JP", "ko": "ko-KR", "es": "es-ES", "fr": "fr-FR", "de": "de-DE",
                   "pt": "pt-BR", "it": "it-IT", "ru": "ru-RU", "hi": "hi-IN", "id": "id-ID", "vi": "vi-VN"]
        return Locale(identifier: map[code] ?? code)
    }

    public static func translationLanguage(_ code: String) -> Locale.Language {
        Locale.Language(identifier: code == "zh" ? "zh-Hans" : code == "pt" ? "pt-BR" : code)
    }

    static func transcriber(_ code: String) async throws -> SpeechTranscriber {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: speechLocale(code)) else {
            throw OnDeviceError.speechUnsupported(code)
        }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                 reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
    }

    public static func speech(_ code: String) async -> Availability {
        guard SpeechTranscriber.isAvailable, let module = try? await transcriber(code) else { return .unsupported }
        switch await AssetInventory.status(forModules: [module]) {
        case .installed: return .installed
        case .downloading: return .downloading
        case .supported: return .downloadable
        default: return .unsupported
        }
    }

    /// Downloads the speech model if needed; `progress` reports 0...1 from an arbitrary thread.
    public static func downloadSpeech(_ code: String, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let module = try await transcriber(code)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
        let observation = request.progress.observe(\.fractionCompleted) { p, _ in progress?(p.fractionCompleted) }
        defer { observation.invalidate() }
        try await request.downloadAndInstall()
    }

    public static func translation(from source: String, to target: String) async -> Availability {
        if source == target { return .installed }
        switch await installedStrategy(from: source, to: target) {
        case .some: return .installed
        case .none:
            let status = await LanguageAvailability().status(from: translationLanguage(source), to: translationLanguage(target))
            return status == .unsupported ? .unsupported : .downloadable
        }
    }

    /// The low-latency model is a separate download; fall back to the standard one when only it is installed.
    static func installedStrategy(from source: String, to target: String) async -> TranslationSession.Strategy? {
        let (s, t) = (translationLanguage(source), translationLanguage(target))
        for strategy in [TranslationSession.Strategy.lowLatency, .highFidelity] {
            if await LanguageAvailability(preferredStrategy: strategy).status(from: s, to: t) == .installed { return strategy }
        }
        return nil
    }

    /// Hand this to SwiftUI's `.translationTask` and call `prepareTranslation()` to show the system download sheet.
    public static func translationDownload(from source: String, to target: String) -> TranslationSession.Configuration {
        TranslationSession.Configuration(source: translationLanguage(source), target: translationLanguage(target), preferredStrategy: .lowLatency)
    }
}

struct Transcript: Sendable {
    let text: String
    let isFinal: Bool
}

/// SpeechAnalyzer fed with the shared 24 kHz PCM16 chunks. `append` must be called from one task at a time.
final class OnDeviceSpeech: @unchecked Sendable {
    let results: AsyncThrowingStream<Transcript, Error>
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let converter: AnalyzerInputConverter
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: PCM16Resampler.sampleRate, channels: 1, interleaved: true)!
    private let reader: Task<Void, Never>

    init(language: String, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await OnDeviceModels.downloadSpeech(language, progress: progress)
        let transcriber = try await OnDeviceModels.transcriber(language)
        converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        self.input = input
        analyzer = SpeechAnalyzer(modules: [transcriber])
        let (results, output) = AsyncThrowingStream<Transcript, Error>.makeStream()
        self.results = results
        reader = Task {
            do {
                for try await result in transcriber.results {
                    output.yield(Transcript(text: String(result.text.characters), isFinal: result.isFinal))
                }
                output.finish()
            } catch { output.finish(throwing: error) }
        }
        try await analyzer.start(inputSequence: stream)
    }

    func append(_ chunk: Data) throws {
        let frames = AVAudioFrameCount(chunk.count / 2)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        chunk.withUnsafeBytes { raw in
            buffer.int16ChannelData![0].update(from: raw.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        for item in try converter.convert(buffer, at: nil) { input.yield(item) }
    }

    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        reader.cancel()
    }
}

/// Owns a non-Sendable TranslationSession and serializes requests to it.
actor OnDeviceTextTranslator {
    private nonisolated(unsafe) let session: TranslationSession

    let strategy: String

    init(source: String, target: String) async throws {
        guard let strategy = await OnDeviceModels.installedStrategy(from: source, to: target) else {
            throw await OnDeviceModels.translation(from: source, to: target) == .unsupported
                ? OnDeviceError.translationUnsupported(source, target) : OnDeviceError.translationNotInstalled(source, target)
        }
        self.strategy = strategy == .lowLatency ? "low-latency" : "standard"
        session = TranslationSession(installedSource: OnDeviceModels.translationLanguage(source),
                                     target: OnDeviceModels.translationLanguage(target), preferredStrategy: strategy)
    }

    func translate(_ text: String) async throws -> String { try await session.translate(text).targetText }
}

public enum LanguageLabel {
    public static func of(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
