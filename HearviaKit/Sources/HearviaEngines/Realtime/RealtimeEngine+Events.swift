import Foundation
import HearviaCore

/// Server events: text, errors, and what to do when a socket closes.
extension RealtimeEngine {
    func handle(_ event: RealtimeEvent, from sender: any RealtimeSocket) {
        guard running else { return }
        if sender === retiring {
            handleRetiring(event)
            return
        }
        guard sender === socket else { return }
        switch event {
        case let .sessionCreated(id, expires):
            lastProblem = ""
            failures = 0
            expiresAt = expires
            continuation.yield(.status(.translating(onDevice: false)))
            continuation.yield(.log("translation_session", ["id": id, "expires": expires.map { "\($0)" } ?? ""]))
        case .sessionUpdated, .audioDelta: break
        case let .sourceDelta(delta, _): appendSource(delta)
        case let .translationDelta(delta, _): appendTranslation(delta)
        case let .serverError(type, code, message):
            lastProblem = "\(code ?? type): \(message)"
            continuation.yield(.problem(lastProblem))
            continuation.yield(.log("translation_error", ["type": type, "code": code ?? "", "message": message]))
        case let .closed(reason):
            continuation.yield(.log("translation_closed", ["reason": reason ?? "session.closed", "chunks": "\(chunksSent)", "deltas": "\(deltas)"]))
            socket = nil
            socketReady = false
            expiresAt = nil
            reconnectOrFail()
        }
    }

    /// A socket closed for a pause or rotation still flushes the translation of its last words.
    private func handleRetiring(_ event: RealtimeEvent) {
        switch event {
        case let .sourceDelta(delta, _): appendSource(delta)
        case let .translationDelta(delta, _): appendTranslation(delta)
        case .closed: retiring = nil
        default: break
        }
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
        if lastProblem.contains("invalid_api_key") || lastProblem.contains("insufficient_quota") || failures >= timing.maxFailures {
            running = false
            pump?.cancel()
            pump = nil
            continuation.yield(.failed(lastProblem.isEmpty ? "Lost the connection to OpenAI." : lastProblem))
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
