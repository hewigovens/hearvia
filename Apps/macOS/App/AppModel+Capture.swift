import AVFoundation
import HearviaKit

extension AppModel {
    func start() async {
        guard !capturing else { return }
        captureError = ""
        let feed = translator.feed
        let meter = meter
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
        Self.emit("capture_started", ["source": source.label, "format": tap.format.map { "\($0)" } ?? "mic"])
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }
                self.levels = Array(self.levels.dropFirst()) + [self.meter.take()]
            }
        }
        await translator.start()
    }

    func stop() async {
        guard capturing else { return }
        tap.stop()
        microphone.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        levels = levels.map { _ in 0 }
        capturing = false
        await translator.stop()
        Self.emit("capture_stopped", ["translation": translator.translation])
    }
}
