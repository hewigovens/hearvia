import HearviaCore
import HearviaEngines

public extension LiveTranslator {
    /// Known without asking the system or the network; nil until `checkSetup()` looks up the key, the local server or the installed models.
    var knownSetup: TranslatorSetup? {
        if engine.isCloud, apiKey.isEmpty {
            .needsKey
        } else if engine == .local, localModel.isEmpty {
            .needsLocalModel
        } else {
            nil
        }
    }

    func checkSetup() async -> TranslatorSetup {
        if let knownSetup {
            return knownSetup
        }
        if engine.isCloud {
            do {
                try await APIKeyCheck(engine, key: apiKey).verify()
                return .ready
            } catch .malformed, .rejected {
                return .keyRejected
            } catch {
                return .unreachable(error.localizedDescription)
            }
        }
        if engine == .local {
            do {
                _ = try await localServer.models()
            } catch {
                return .unreachable(error.localizedDescription)
            }
        }
        let installed = if engine == .onDevice {
            await OnDeviceModels.isReady(from: sourceLanguage, to: targetLanguage)
        } else if sourceLanguage.isEmpty {
            await !OnDeviceModels.autoCandidates().isEmpty
        } else {
            await OnDeviceModels.speech(sourceLanguage) == .installed
        }
        return installed ? .ready : .needsModels
    }

    /// Changes whenever `checkSetup()` might; use it as a `.task(id:)`. Keys appear only as hashes.
    var readinessKey: String {
        "\(engine.rawValue)>\(sourceLanguage)>\(targetLanguage)>\(apiKey.hashValue)>\(localServerURL)>\(localKey.hashValue)>\(localModel)"
    }

    var languagePair: String {
        LanguageName.pair(source: engine.detectsSpokenLanguage ? "" : sourceLanguage, target: targetLanguage)
    }

    /// One line for while listening; each app names its own audio source.
    func summary(listeningTo source: String) -> String {
        "\(source) · \(languagePair) · \(engine.shortTitle)"
    }

    /// The history without the session in progress, which the transcript lists show as "Now".
    var savedTranscripts: [Transcript] {
        history.transcripts.filter { !isActive || $0.id != transcript.id }
    }

    func transcripts(matching query: String) -> TranscriptMatches {
        TranscriptMatches(query: query, live: isActive ? transcript : nil, saved: savedTranscripts)
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
