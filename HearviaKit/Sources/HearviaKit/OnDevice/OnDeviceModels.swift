import Speech
import Translation

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

    /// Both the speech and translation models are installed, so the on-device engine can start offline.
    public static func isReady(from source: String, to target: String) async -> Bool {
        let speech = await speech(source)
        let text = await translation(from: source, to: target)
        return speech == .installed && text == .installed
    }

    public static func translation(from source: String, to target: String) async -> Availability {
        if source == target {
            return .installed
        }
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
        for strategy in [TranslationSession.Strategy.lowLatency, .highFidelity]
            where await LanguageAvailability(preferredStrategy: strategy).status(from: s, to: t) == .installed {
            return strategy
        }
        return nil
    }

    /// Hand this to SwiftUI's `.translationTask` and call `prepareTranslation()` to show the system download sheet.
    public static func translationDownload(from source: String, to target: String) -> TranslationSession.Configuration {
        TranslationSession.Configuration(source: translationLanguage(source), target: translationLanguage(target), preferredStrategy: .lowLatency)
    }
}
