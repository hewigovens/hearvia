import Foundation

extension AppModel {
    private func startListening() {
        switch settings.input {
        case .otherApps: capture.start()
        case .microphone: Task { await startMicrophone() }
        }
    }

    var busy: Bool {
        capture.pending || micStarting
    }

    func toggleListening() async {
        if listening || busy {
            await stopListening()
        } else {
            startListening()
        }
    }

    var errorMessage: String {
        [translation.displayError, capture.error, micError].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    func stopListening() async {
        if micRunning || micStarting {
            microphone.stop()
            micRunning = false
            session.release("mic-input")
            log.event("mic_stopped")
        } else {
            await capture.stop()
        }
        pip.stop()
        await tick() // Stop translation now rather than on the next timer tick.
    }

    /// Arming needs an active session, so it waits for listening.
    func updateFloating() async {
        if settings.floatsWhenLeaving, listening {
            await pip.armAutoStart()
        } else if !settings.floatsWhenLeaving {
            pip.disarmAutoStart()
        }
    }

    func syncListeningState() async {
        guard listening != wasListening else { return }
        wasListening = listening
        listeningSince = listening ? Date() : nil
        if listening {
            if subtitlesVisible {
                levels.start()
            }
            if settings.floatsWhenLeaving {
                await pip.armAutoStart()
            }
            if translationEnabled {
                translation.listensToMicrophone = micRunning
                await translation.start()
            }
        } else {
            levels.stop()
            lastHealth = nil // The next session's first CPU reading starts fresh.
            pip.disarmAutoStart()
            await translation.stop()
        }
    }

    private func startMicrophone() async {
        guard !micRunning, !micStarting else { return }
        micStarting = true
        micError = ""
        defer { micStarting = false }
        let feed = translation.feed, meter = levels.meter
        do {
            try await session.acquire("mic-input", microphone: true)
            try await microphone.start { buffer in
                meter.measure(buffer)
                feed.push(buffer)
            }
            micRunning = true
            log.event("mic_started", ["route": session.route])
            await tick()
        } catch {
            micError = error.localizedDescription
            session.release("mic-input")
            log.event("mic_error", ["error": "\(error)"])
        }
    }
}
