import HearviaCore
import HearviaEngines

/// What the setup tiles show about the current preferences.
public extension LiveTranslator {
    /// Whether Start translates right away: a cloud engine needs its API key, on-device needs its models, and a
    /// downloadable engine its download plus Apple's speech model.
    func isReady() async -> Bool {
        switch engine {
        case .realtime, .gemini: !apiKey.isEmpty
        case .onDevice: await OnDeviceModels.isReady(from: sourceLanguage, to: targetLanguage)
        case .gemma: downloadable(for: engine)?.isDownloaded == true ? await OnDeviceModels.speech(sourceLanguage) == .installed : false
        }
    }

    /// Changes whenever `isReady()` might; use it as a `.task(id:)`.
    var readinessKey: String {
        "\(engine.rawValue)>\(sourceLanguage)>\(targetLanguage)>\(apiKey.isEmpty)>\(downloadable(for: engine)?.isDownloaded ?? true)"
    }

    /// The engines to offer: a downloadable one only when the app provides it and this device can run it.
    var engines: [EngineKind] {
        EngineKind.allCases.filter { $0 != .gemma || downloadable(for: $0)?.isSupported == true }
    }

    func downloadable(for kind: EngineKind) -> (any DownloadableEngine)? {
        downloadable.first { $0.kind == kind }
    }

    /// "English → 中文", or "Auto → 中文" when the engine detects the spoken language.
    var languagePair: String {
        LanguageName.pair(source: engine.detectsSpokenLanguage ? "" : sourceLanguage, target: targetLanguage)
    }
}
