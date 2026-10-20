import Foundation
import HearviaCore
import HearviaEngines

/// Updates from an engine that is no longer running are ignored.
public extension LiveTranslator {
    func start() async {
        guard !isActive else { return }
        switch knownSetup {
        case .needsKey:
            status = .needsAPIKey
            error = String(localized: "Add an API key for \(engine.title) in Settings, or switch to on-device translation.")
            return
        case .needsLocalModel:
            error = LocalModelError.noModel.localizedDescription
            return
        default: break
        }
        isActive = true
        error = ""
        source = ""
        translation = ""
        transcript = Transcript(engine: engine, sourceLanguage: engine.detectsSpokenLanguage ? "" : sourceLanguage, targetLanguage: targetLanguage)
        stats = TranslatorStats()
        let request = EngineRequest(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, apiKey: apiKey,
                                    transcribesSource: transcribesSource, microphone: listensToMicrophone,
                                    localServer: localServer, localModel: localModel)
        let engine = makeEngine(engine, request)
        running = engine
        listener = Task { [weak self] in
            for await update in engine.updates {
                self?.apply(update, from: engine)
            }
        }
        await engine.start(audio: feed.open())
    }

    /// Writes the current transcript to the history now, e.g. before the app quits or is suspended mid-session.
    func saveTranscript() {
        if savesTranscripts {
            history.save(transcript)
        }
    }

    func stop() async {
        guard isActive else { return }
        let engine = endRun()
        status = .stopped
        await engine?.stop()
    }

    internal func apply(_ update: EngineUpdate, from engine: any TranslationEngine) {
        guard engine === running else { return }
        switch update {
        case let .status(status):
            self.status = status
            if case let .connecting(attempt) = status {
                stats.reconnects = attempt
            }
            if case .translating = status {
                error = ""
            }
        case let .text(source, translation):
            if translation != self.translation {
                stats.deltas += 1
                stats.lastDeltaUptime = ProcessInfo.processInfo.systemUptime
            }
            self.source = source
            self.translation = translation
            onTextChange?()
        case let .sentence(source, translation):
            transcript.append(source: source, translation: translation)
            if transcript.lines.count.isMultiple(of: 10) {
                saveTranscript() // A crash or kill mid-session loses at most the last few sentences.
            }
        case .audioConsumed:
            stats.chunksSent += 1
        case let .problem(message):
            error = message
        case let .failed(message):
            error = message
            status = .failed
            endRun()
        case let .log(name, fields):
            onLog?(name, fields)
        }
    }

    /// Clears the current run and returns its engine for the caller to stop (a failed engine has already stopped).
    @discardableResult
    private func endRun() -> (any TranslationEngine)? {
        let engine = running
        running = nil
        isActive = false
        transcript.endedAt = .now
        saveTranscript()
        feed.close()
        listener?.cancel()
        listener = nil
        return engine
    }
}
