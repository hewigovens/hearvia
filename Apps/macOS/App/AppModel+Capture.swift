import AVFoundation

extension AppModel {
    func start() async {
        guard !capturing else { return }
        captureError = ""
        let feed = translator.feed
        let meter = levels.meter
        let sink: @Sendable (AVAudioPCMBuffer) -> Void = { buffer in
            meter.measure(buffer)
            feed.push(buffer)
        }
        do {
            switch source {
            case .allApps: try tap.start(processes: nil, onBuffer: sink)
            case let .process(p): try tap.start(processes: [p.id], onBuffer: sink)
            case .microphone: try await microphone.start(onBuffer: sink)
            }
        } catch {
            captureError = error.localizedDescription
            Self.emit("capture_error", ["error": captureError])
            return
        }
        capturing = true
        capturingSince = Date()
        Self.emit("capture_started", ["source": source.label, "format": tap.format.map { "\($0)" } ?? "mic"])
        levels.start()
        translator.listensToMicrophone = source == .microphone
        await translator.start()
    }

    func stop() async {
        guard capturing else { return }
        tap.stop()
        microphone.stop()
        levels.stop()
        capturing = false
        capturingSince = nil
        await translator.stop()
        Self.emit("capture_stopped", ["translation": translator.translation])
    }
}
