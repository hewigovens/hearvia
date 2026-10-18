import HearviaCore
import Speech
import Translation

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

    public static func spokenLanguages() async -> [String] {
        guard SpeechTranscriber.isAvailable else { return [] }
        return await codes(SpeechTranscriber.supportedLocales.map(\.language))
    }

    public static func subtitleLanguages() async -> [String] {
        await codes(LanguageAvailability().supportedLanguages)
    }

    private static func codes(_ languages: [Locale.Language]) -> [String] {
        let special: Set = ["mul", "und", "zxx", "mis"] // multiple, undetermined, no content, uncoded
        return Array(Set(languages.compactMap { $0.languageCode?.identifier }).subtracting(special))
    }

    public static func translationLanguage(_ code: String) -> Locale.Language {
        Locale.Language(identifier: code == "zh" ? "zh-Hans" : code == "pt" ? "pt-BR" : code)
    }

    static func transcriber(_ code: String, confidence: Bool = false) async throws -> SpeechTranscriber {
        var locale = await SpeechTranscriber.supportedLocale(equivalentTo: speechLocale(code))
        if locale == nil { // Languages outside the region map: take any supported variant.
            locale = await SpeechTranscriber.supportedLocales.first { $0.language.languageCode?.identifier == code }
        }
        guard let locale else { throw OnDeviceError.speechUnsupported(code) }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                 reportingOptions: [.volatileResults, .fastResults], attributeOptions: confidence ? [.transcriptionConfidence] : [])
    }

    /// Every recognizer runs at once until one wins, so Auto tries at most three: installed languages, the user's own first.
    public static func autoCandidates() async -> [String] {
        guard SpeechTranscriber.isAvailable else { return [] }
        let installed = await Set(SpeechTranscriber.installedLocales.compactMap { $0.language.languageCode?.identifier })
        let preferred = Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        let ordered = preferred + Languages.supported + installed.sorted()
        var seen = Set<String>()
        return Array(ordered.filter { installed.contains($0) && seen.insert($0).inserted }.prefix(3))
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

    /// `progress` reports 0...1 from an arbitrary thread.
    public static func downloadSpeech(_ code: String, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let module = try await transcriber(code)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
        let observation = request.progress.observe(\.fractionCompleted) { p, _ in progress?(p.fractionCompleted) }
        defer { observation.invalidate() }
        try await request.downloadAndInstall()
    }

    public static func isReady(from source: String, to target: String) async -> Bool {
        if source.isEmpty {
            return await !autoCandidates().isEmpty
        }
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
