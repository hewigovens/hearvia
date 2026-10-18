#if targetEnvironment(simulator)
    import Observation

    /// Stands in for the ScreenCaptureKit capture, which the Simulator SDK lacks, so the app runs there (layouts, UI tests); the microphone still works.
    @MainActor @Observable
    final class CaptureController {
        var state = "Idle"
        var error = ""
        var excludeOwnAudio = true
        var offerMicrophone = false
        var microphoneEnabled = false
        var running = false
        var pending = false
        var stopping = false
        var captureStart: Double?
        let probe: AudioProbe

        init(log: DiagnosticLog, session _: AudioSessionController) {
            probe = AudioProbe(log: log)
        }

        func start() {
            error = String(localized: "Other apps' audio isn't available in the Simulator. Use the microphone.")
        }

        func stop() async {}
    }
#endif
