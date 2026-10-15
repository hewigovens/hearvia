import Foundation
import HearviaCore
import HearviaEngines

/// Starting, stopping and applying one engine run. Updates from an engine that is no longer running are ignored.
public extension LiveTranslator {
    func start() async {
        guard !isActive else { return }
        guard !engine.isCloud || !apiKey.isEmpty else {
            status = .needsAPIKey
            error = "Add an API key for \(engine.title) in Settings, or switch to on-device translation."
            return
        }
        isActive = true
        error = ""
        source = ""
        translation = ""
        transcript = Transcript()
        stats = TranslatorStats()
        let engine = makeEngine(engine, EngineRequest(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, apiKey: apiKey,
                                                      transcribesSource: transcribesSource))
        running = engine
        listener = Task { [weak self] in
            for await update in engine.updates {
                self?.apply(update, from: engine)
            }
        }
        await engine.start(audio: feed.open())
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
        feed.close()
        listener?.cancel()
        listener = nil
        return engine
    }
}
