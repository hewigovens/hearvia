import Foundation

extension AppModel {
    func scheduleRender() {
        guard !renderQueued else { return }
        renderQueued = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            renderQueued = false
            await renderSubtitle()
        }
    }

    func renderSubtitle() async {
        pip.fontScale = settings.subtitleScale
        let lines = translation.subtitleLines(originalLarge: settings.originalLarge, showsSecond: settings.showsOriginal)
        let subtitle: String = if diagnosticsInPiP {
            String(format: "System RMS %.5f\n%@", audio.system.rms, captureLabel)
        } else if !lines.main.isEmpty {
            lines.main
        } else if translation.isActive {
            String(localized: "Listening…")
        } else if listening {
            String(localized: "Connecting…")
        } else {
            String(localized: "Subtitles appear here")
        }
        await pip.render(subtitle: subtitle, second: diagnosticsInPiP ? nil : lines.second, detail: statusLineInPiP ? statusLine : nil)
    }

    private var captureLabel: String {
        if micRunning {
            return "Microphone"
        }
        guard capture.running else { return capture.state }
        let elapsed = capture.captureStart.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0
        return String(format: "Capture %.0f s", elapsed)
    }

    private var statusLine: String {
        let now = ProcessInfo.processInfo.systemUptime
        let lag = translation.stats.lastDeltaUptime.map { String(format: "text %.0fs ago", now - $0) } ?? "no text"
        let pcm = audio.system.age.map { String(format: "%.1fs", $0) } ?? "none"
        return "#\(tickCount) · \(scene) · PCM \(pcm) · \(translation.status.label) · \(lag)"
    }
}
