import HearviaCore
import HearviaEngines

/// What the setup tiles show about the current preferences.
public extension LiveTranslator {
    /// Whether Start translates right away: a cloud engine needs its API key, on-device needs its models.
    func isReady() async -> Bool {
        engine.isCloud ? !apiKey.isEmpty : await OnDeviceModels.isReady(from: sourceLanguage, to: targetLanguage)
    }

    /// Changes whenever `isReady()` might; use it as a `.task(id:)`.
    var readinessKey: String {
        "\(engine.rawValue)>\(sourceLanguage)>\(targetLanguage)>\(apiKey.isEmpty)"
    }

    /// "English → 中文", or "Auto → 中文" when the engine detects the spoken language.
    var languagePair: String {
        LanguageName.pair(source: engine.detectsSpokenLanguage ? "" : sourceLanguage, target: targetLanguage)
    }
}
