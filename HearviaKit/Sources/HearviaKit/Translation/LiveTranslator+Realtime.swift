import Foundation

extension LiveTranslator {
    func connect(_ attempt: Int) async {
        guard active, attempt == generation else { return }
        state = reconnects == 0 ? "Connecting" : "Reconnecting (\(reconnects))"
        let client = RealtimeTranslationClient(configuration: .init(targetLanguage: targetLanguage), credential: apiKey)
        self.client = client
        Task { [weak self] in
            for await event in client.events {
                self?.handle(event, from: client)
            }
        }
        do {
            try await client.connect()
            onLog?("translation_connected", ["target": targetLanguage, "reconnects": "\(reconnects)"])
        } catch {
            handle(.closed(reason: error.localizedDescription), from: client)
        }
    }

    func handle(_ event: TranslationEvent, from sender: RealtimeTranslationClient) {
        guard sender === client else { return }
        switch event {
        case let .sessionCreated(id, expires):
            state = "Translating"
            error = ""
            onLog?("translation_session", ["id": id, "expires": expires.map { "\($0)" } ?? ""])
        case .sessionUpdated, .audioDelta: break
        case let .sourceDelta(d, _): source = Self.trim(source + d)
            pendingSource += d
            onTextChange?()
        case let .translationDelta(d, _):
            translation = Self.trim(translation + d)
            deltas += 1
            pendingTranslation += d
            commitRealtimeSentences()
            lastDeltaUptime = ProcessInfo.processInfo.systemUptime
            onTextChange?()
        case let .serverError(type, code, message):
            error = "\(code ?? type): \(message)"
            onLog?("translation_error", ["type": type, "code": code ?? "", "message": message])
        case let .closed(reason):
            onLog?("translation_closed", ["reason": reason ?? "session.closed", "chunks": "\(chunksSent)", "deltas": "\(deltas)"])
            client = nil
            guard active else { return }
            // Fatal auth/config errors would loop forever; stop instead.
            if error.contains("invalid_api_key") || error.contains("insufficient_quota") || reconnects >= 20 {
                active = false
                feed.close()
                pump?.cancel()
                state = "Failed"
                return
            }
            reconnects += 1
            let attempt = generation
            let delay = min(10.0, 0.5 * Double(1 << min(reconnects, 5)))
            state = "Reconnecting in \(Int(delay.rounded(.up))) s"
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                await self?.connect(attempt)
            }
        }
    }
}
