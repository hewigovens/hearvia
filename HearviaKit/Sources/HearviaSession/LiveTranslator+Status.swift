import HearviaCore
import HearviaEngines

public extension LiveTranslator {
    func isReady() async -> Bool {
        switch engine {
        case .realtime, .gemini: !apiKey.isEmpty
        case .onDevice: await OnDeviceModels.isReady(from: sourceLanguage, to: targetLanguage)
        case .local:
            if localModel.isEmpty {
                false
            } else if sourceLanguage.isEmpty {
                await !OnDeviceModels.autoCandidates().isEmpty
            } else {
                await OnDeviceModels.speech(sourceLanguage) == .installed
            }
        }
    }

    /// Changes whenever `isReady()` might; use it as a `.task(id:)`.
    var readinessKey: String {
        "\(engine.rawValue)>\(sourceLanguage)>\(targetLanguage)>\(apiKey.isEmpty)>\(localModel)"
    }

    var languagePair: String {
        LanguageName.pair(source: engine.detectsSpokenLanguage ? "" : sourceLanguage, target: targetLanguage)
    }

    /// The large subtitle line and, when `showsSecond`, the small one above it: the translation is large unless `originalLarge`.
    func subtitleLines(originalLarge: Bool, showsSecond: Bool) -> (main: String, second: String?) {
        let (main, second) = originalLarge ? (source, translation) : (translation, source)
        return (main, showsSecond && !main.isEmpty && !second.isEmpty ? second : nil)
    }
}

public extension LiveTranslator {
    /// `error` in plain words when the provider rejected the key or ran out of quota.
    var displayError: String {
        if error.contains("invalid_api_key") || error.contains("API key not valid") {
            return String(localized: "The \(engine.title) key was rejected. Check it in Settings.")
        }
        if error.contains("insufficient_quota") || error.contains("RESOURCE_EXHAUSTED") {
            return String(localized: "\(engine.title) has no remaining quota for this key. Try the on-device translator.")
        }
        return error
    }
}
