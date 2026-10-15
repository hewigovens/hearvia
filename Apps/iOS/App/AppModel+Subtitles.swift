import Foundation
import HearviaKit

extension AppModel {
    /// Coalesce translation deltas into at most ~5 PiP frames per second.
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
        let translated = translation.translation
        let subtitle: String = if diagnosticsInPiP {
            String(format: "System RMS %.5f\n%@", audio.system.rms, captureLabel)
        } else if !translated.isEmpty {
            translated
        } else {
            translation.active ? "Listening…" : listening ? "Connecting…" : "Subtitles appear here"
        }
        let original = settings.showsOriginal && !diagnosticsInPiP && !translated.isEmpty ? translation.source : nil
        await pip.render(subtitle: subtitle, original: original, detail: statusLineInPiP ? statusLine : nil)
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
        let lag = translation.lastDeltaUptime.map { String(format: "text %.0fs ago", now - $0) } ?? "no text"
        let pcm = audio.system.age.map { String(format: "%.1fs", $0) } ?? "none"
        return "#\(tickCount) · \(scene) · PCM \(pcm) · \(translation.state) · \(lag)"
    }
}
