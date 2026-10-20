import UIKit

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

    /// Nothing shows subtitles in the background without the floating window, or once the screen locks (protected data goes away); then skip drawing, level bars and draft translations, since the transcript only needs finished sentences.
    func updateSubtitleVisibility() {
        let visible = scene != "background" || (pip.active && UIApplication.shared.isProtectedDataAvailable)
        guard visible != subtitlesVisible else { return }
        subtitlesVisible = visible
        translation.translatesDrafts = visible
        if visible, listening {
            levels.start()
        } else {
            levels.stop()
        }
        if visible {
            scheduleRender()
        }
        log.event("subtitles_visible", ["value": "\(visible)"])
    }

    func renderSubtitle() async {
        guard subtitlesVisible else { return }
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
