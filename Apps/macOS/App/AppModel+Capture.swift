import AVFoundation

extension AppModel {
    func start() async {
        guard !capturing, !starting else { return }
        let initialSource = warmSession?.request == warmRequest ? warmSession?.captions?.snapshot() ?? "" : ""
        starting = true
        defer { starting = false }
        warmSession?.stop()
        warmSession = nil
        warmStatus = ""
        captureError = ""
        let feed = translator.feed
        let meter = levels.meter
        let sink: @Sendable (AVAudioPCMBuffer) -> Void = { buffer in
            meter.measure(buffer)
            feed.push(buffer)
        }
        do {
            try await source.start(tap: tap, microphone: microphone, sink: sink)
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
        await translator.start(initialSource: initialSource)
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
