import Foundation

extension AppModel {
    func startListening() {
        switch settings.input {
        case .otherApps: capture.start()
        case .microphone: Task { await startMicrophone() }
        }
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

    /// Follows the toggle in Settings; arming needs an active session, so it waits for listening.
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
        levelTimer?.invalidate()
        levelTimer = nil
        levels = levels.map { _ in 0 }
        if listening {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.levels = Array(self.levels.dropFirst()) + [self.meter.take()]
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            levelTimer = timer
            if settings.floatsWhenLeaving {
                await pip.armAutoStart()
            }
            if translationEnabled {
                await translation.start()
            }
        } else {
            pip.disarmAutoStart()
            await translation.stop()
        }
    }

    private func startMicrophone() async {
        guard !micRunning, !micStarting else { return }
        micStarting = true
        micError = ""
        defer { micStarting = false }
        let feed = translation.feed, meter = meter
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
