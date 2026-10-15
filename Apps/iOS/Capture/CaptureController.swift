@preconcurrency import ScreenCaptureKit
import AVFoundation
import Observation

@MainActor @Observable
final class CaptureController: NSObject, SCContentSharingPickerObserver, SCStreamDelegate {
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
    private let log: DiagnosticLog
    private let session: AudioSessionController
    private let picker = SCContentSharingPicker.shared
    private var stream: SCStream?
    private var generation = 0
    private var starting = false

    init(log: DiagnosticLog, session: AudioSessionController) {
        self.log = log; self.session = session; probe = AudioProbe(log: log)
        super.init()
        picker.add(self)
    }

    func start() {
        guard !running, !pending, !stopping else { return }
        guard picker.isAvailable else { state = "Unavailable"; error = "Screen capture is unavailable or restricted on this device."; return }
        var config = SCContentSharingPickerConfiguration()
        config.showsMicrophoneControl = offerMicrophone
        picker.defaultConfiguration = config
        picker.isActive = true
        pending = true; state = "Awaiting system consent"; error = ""
        log.event("picker_presented", ["full_display": "true", "microphone_control": "\(offerMicrophone)", "exclude_own_audio": "\(excludeOwnAudio)"])
        picker.present() // iOS full-display entry point in Apple's iOS 27 sample.
    }

    func stop() async {
        guard !stopping else { return }
        stopping = true
        defer { stopping = false }
        generation += 1
        pending = false; starting = false
        let old = stream
        stream = nil; running = false; state = "Stopping"
        probe.unbind()
        if let old { do { try await old.stopCapture() } catch { self.error = error.localizedDescription; log.event("stop_error", ["error": "\(error)"]) } }
        probe.finishRecording()
        picker.isActive = false; microphoneEnabled = false
        session.release("microphone")
        state = "Stopped"; log.event("capture_stopped")
    }

    private func configuration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = excludeOwnAudio
        config.sampleRate = 48000; config.channelCount = 2
        config.width = 320; config.height = 568
        return config
    }

    private func begin(_ filter: SCContentFilter) async {
        guard pending, !starting else { return }
        generation += 1; let attempt = generation
        starting = true
        defer { if attempt == generation { starting = false } }
        state = "Starting"
        do {
            guard filter.style == .display else { throw NSError(domain: "Hearvia", code: 1, userInfo: [NSLocalizedDescriptionKey: "A full-display filter is required."]) }
            await probe.reset()
            guard attempt == generation, pending else { return }
            microphoneEnabled = filter.isMicrophoneEnabled
            log.event("picker_authorized", ["style": "\(filter.style.rawValue)", "microphone": "\(microphoneEnabled)"])
            if microphoneEnabled { try await session.acquire("microphone", microphone: true) }
            guard attempt == generation, pending else { session.release("microphone"); return }
            let candidate = SCStream(filter: filter, configuration: configuration(), delegate: self)
            try candidate.addStreamOutput(probe, type: .screen, sampleHandlerQueue: probe.queue)
            try candidate.addStreamOutput(probe, type: .audio, sampleHandlerQueue: probe.queue)
            if microphoneEnabled { try candidate.addStreamOutput(probe, type: .microphone, sampleHandlerQueue: probe.queue) }
            await probe.bind(candidate)
            guard attempt == generation, pending else { probe.unbind(); return }
            stream = candidate
            try await candidate.startCapture()
            guard attempt == generation, stream === candidate else { try? await candidate.stopCapture(); return }
            pending = false; running = true; captureStart = ProcessInfo.processInfo.systemUptime
            state = "Capturing full display"
            log.event("capture_started", ["requested_rate": "48000", "requested_channels": "2", "exclude_own_audio": "\(excludeOwnAudio)"])
        } catch {
            guard attempt == generation else { return }
            self.error = error.localizedDescription; state = "Failed"; pending = false; running = false
            stream = nil; picker.isActive = false; session.release("microphone")
            probe.unbind()
            log.event("capture_error", ["error": "\(error)"])
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.pending = false; self.state = "Picker cancelled"; self.picker.isActive = false
            self.log.event("picker_cancelled")
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in await self.begin(filter) }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        let message = String(describing: error)
        Task { @MainActor in
            self.pending = false; self.state = "Picker failed"; self.error = message
            self.picker.isActive = false; self.log.event("picker_error", ["error": message])
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        let message = String(describing: error)
        Task { @MainActor in
            guard self.stream === stream else { return }
            self.generation += 1; self.running = false; self.pending = false; self.state = "Stream ended"
            self.error = message; self.stream = nil; self.picker.isActive = false
            self.probe.unbind()
            self.probe.finishRecording(); self.session.release("microphone")
            self.log.event("stream_ended", ["error": message])
        }
    }
}
