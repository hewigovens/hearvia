import Foundation
import HearviaCore

extension CloudEngine {
    func handle(_ event: SocketEvent, from sender: any TranslationSocket) {
        guard running else { return }
        if sender === retiring {
            handleRetiring(event)
            return
        }
        guard sender === socket else { return }
        switch event {
        case let .sessionStarted(id, expires):
            lastProblem = ""
            failures = 0
            expiresAt = expires
            sessionStartedSource = true
            sessionStartedTranslation = true
            continuation.yield(.status(.translating(onDevice: false)))
            continuation.yield(.log("translation_session", ["provider": provider, "id": id, "expires": expires.map { "\($0)" } ?? ""]))
        case let .expiring(at):
            expiresAt = at
            continuation.yield(.log("translation_expiring", ["seconds_left": "\(Int(at.timeIntervalSince(timing.now())))"]))
        case .audioDelta: break
        case let .sourceDelta(delta, _): appendSource(startingSession(delta, isSource: true))
        case let .translationDelta(delta, _): appendTranslation(startingSession(delta, isSource: false))
        case let .serverError(code, message, fatal):
            lastProblem = "\(code): \(message)"
            fatalProblem = fatalProblem || fatal
            continuation.yield(.problem(lastProblem))
            continuation.yield(.log("translation_error", ["code": code, "message": message, "fatal": "\(fatal)"]))
        case let .closed(reason):
            continuation.yield(.log("translation_closed", ["reason": reason ?? "session.closed", "chunks": "\(chunksSent)", "deltas": "\(deltas)"]))
            socket = nil
            socketReady = false
            expiresAt = nil
            reconnectOrFail()
        }
    }

    /// A socket closed for a pause or rotation still flushes the translation of its last words.
    private func handleRetiring(_ event: SocketEvent) {
        switch event {
        case let .sourceDelta(delta, _): appendSource(delta)
        case let .translationDelta(delta, _): appendTranslation(delta)
        case .closed: retiring = nil
        default: break
        }
    }

    private func startingSession(_ delta: String, isSource: Bool) -> String {
        if isSource, sessionStartedSource {
            sessionStartedSource = false
            return SubtitleText.continuation(of: source, with: delta)
        }
        if !isSource, sessionStartedTranslation {
            sessionStartedTranslation = false
            return SubtitleText.continuation(of: translation, with: delta, unspaced: Languages.unspaced.contains(targetLanguage))
        }
        return delta
    }

    private func appendSource(_ delta: String) {
        source = SubtitleText.bounded(source + delta)
        segmenter.appendSource(delta)
        continuation.yield(.text(source: source, translation: translation))
    }

    private func appendTranslation(_ delta: String) {
        translation = SubtitleText.bounded(translation + delta)
        deltas += 1
        if let sentence = segmenter.appendTranslation(delta) {
            continuation.yield(.sentence(source: sentence.source, translation: sentence.translation))
        }
        continuation.yield(.text(source: source, translation: translation))
    }

    private func reconnectOrFail() {
        // Fatal auth/quota errors would loop forever; give up instead.
        if fatalProblem || failures >= timing.maxFailures {
            running = false
            pump?.cancel()
            pump = nil
            continuation.yield(.failed(lastProblem.isEmpty ? "Lost the connection to \(provider)." : lastProblem))
            continuation.finish()
            return
        }
        if silentChunks >= timing.silenceChunks {
            pause()
            return
        }
        failures += 1
        reconnects += 1
        let delay = timing.backoff(failures)
        let seconds = Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
        continuation.yield(.status(.reconnecting(inSeconds: Int(seconds.rounded(.up)))))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.connect()
        }
    }
}
