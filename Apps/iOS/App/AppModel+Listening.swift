import Foundation

extension AppModel {
    var busy: Bool {
        capture.pending || micStarting
    }

    func toggleListening() async {
        if listening || busy {
            await stopListening()
        } else {
            switch settings.input {
            case .otherApps: capture.start()
            case .microphone: await startMicrophone()
            }
        }
    }

    var errorMessage: String {
        [translation.displayError, capture.error, micError].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    func stopListening() async {
        if micRunning || micStarting {
            micStartCancelled = true
            translation.feed.discardOpeningAudio()
            microphone.stop()
            micRunning = false
            session.release("mic-input")
            log.event("mic_stopped")
        } else {
            await capture.stop()
        }
        pip.stop()
        await syncListeningState() // Inside tick (auto-stop) the tick below returns early, so translation must stop here.
        await tick()
    }

    /// Arming needs an active session, so it waits for listening.
    func updateFloating() async {
        if settings.floatsWhenLeaving, listening {
            await pip.armAutoStart()
        } else if !settings.floatsWhenLeaving {
            pip.disarmAutoStart()
        }
    }

    func prepareCaptureAudio() {
        if translationEnabled, !translation.isActive {
            translation.feed.prepareForCapture()
        }
    }

    func syncListeningState(initialSource: String = "") async {
        guard listening != wasListening else { return }
        wasListening = listening
        listeningSince = listening ? Date() : nil
        if listening {
            if subtitlesVisible {
                levels.start()
            }
            async let floating: Void = updateFloating()
            if translationEnabled {
                translation.listensToMicrophone = micRunning
                await translation.start(initialSource: initialSource)
            } else {
                translation.feed.discardOpeningAudio()
            }
            await floating
        } else {
            levels.stop()
            lastHealth = nil // The next session's first CPU reading starts fresh.
            pip.disarmAutoStart()
            await translation.stop()
        }
    }

    private func startMicrophone() async {
        guard !micRunning, !micStarting else { return }
        let initialSource = warmMicrophone?.languageRequest == standbyLanguage ? warmMicrophone?.captions?.snapshot() ?? "" : ""
        stopStandby()
        micStarting = true
        micStartCancelled = false
        micError = ""
        defer { micStarting = false }
        let feed = translation.feed, meter = levels.meter
        do {
            try await session.acquire("mic-input", microphone: true)
            guard !micStartCancelled else { return }
            prepareCaptureAudio()
            try await microphone.start { buffer in
                meter.measure(buffer)
                feed.push(buffer)
            }
            guard !micStartCancelled else {
                microphone.stop()
                return
            }
            micRunning = true
            log.event("mic_started", ["route": session.route])
            await syncListeningState(initialSource: initialSource)
        } catch {
            translation.feed.discardOpeningAudio()
            micError = error.localizedDescription
            session.release("mic-input")
            log.event("mic_error", ["error": "\(error)"])
        }
    }
}
