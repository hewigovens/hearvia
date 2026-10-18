@preconcurrency import AVKit
import Observation
import SwiftUI

@MainActor @Observable
final class PiPController: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    var state = "Preparing inline layer"
    var error = ""
    var possible = false
    var active = false
    var pending = false
    var playing = true
    var frames = 0
    var renderSize = "Not reported"
    var restoreRequested = false
    private(set) var autoStartArmed = false
    var onClose: (() -> Void)?
    let previewView = SubtitlePreviewView()
    var fontScale = 1.0 {
        didSet { renderer?.fontScale = fontScale }
    }
    private let log: DiagnosticLog
    private let session: AudioSessionController
    private var controller: AVPictureInPictureController?
    private var renderer: SubtitleRenderer?
    private var observation: NSKeyValueObservation?
    private var lastFrameUptime: Double?
    private var rendering = false
    private var restoreCompletion: ((Bool) -> Void)?
    private nonisolated let playbackFlag = LockedFlag(true)
    // Set synchronously so the stop callback can tell ✕ apart from Back to app and from `stop()`.
    private nonisolated let returningToApp = LockedFlag(false)
    private nonisolated let stopRequested = LockedFlag(false)

    init(log: DiagnosticLog, session: AudioSessionController) {
        self.log = log
        self.session = session
    }

    func attach(_ layer: AVSampleBufferDisplayLayer) {
        guard renderer == nil else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { state = "Unsupported device"
            return
        }
        do {
            renderer = try SubtitleRenderer(layer: layer)
            renderer?.fontScale = fontScale
            let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
            controller = AVPictureInPictureController(contentSource: source)
            controller?.delegate = self
            controller?.requiresLinearPlayback = true
            controller?.canStartPictureInPictureAutomaticallyFromInline = false
            observation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
                let value = change.newValue ?? false
                Task { @MainActor [weak self] in
                    self?.possible = value
                    self?.log.event("pip_possible", ["value": "\(value)"])
                }
            }
            state = "Inline ready"
            Task { await self.render(subtitle: "Subtitles appear here", detail: nil) }
        } catch { fail(error) }
    }

    func start() {
        guard let controller, !active, !pending else { return }
        pending = true
        state = "Activating PiP session"
        error = ""
        Task { await startFromUserAction(controller) }
    }

    private func startFromUserAction(_ controller: AVPictureInPictureController) async {
        do {
            try await session.acquire("pip")
            playing = true
            playbackFlag.set(true)
            renderer?.setPlaying(true)
            controller.invalidatePlaybackState()
            log.event("pip_start_requested", ["possible": "\(possible)"])
            // Readiness changed ~40 ms after activation on the device. Keep this user request pending while KVO catches up, rather than making the first tap fail.
            for _ in 0 ..< 30 {
                if controller.isPictureInPicturePossible {
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
            guard controller.isPictureInPicturePossible else {
                error = "PiP is not ready. Keep the inline preview visible, then retry."
                pending = false
                state = "PiP unavailable"
                session.release("pip")
                return
            }
            state = "Starting PiP"
            controller.startPictureInPicture()
        } catch { pending = false
            fail(error)
            session.release("pip")
        }
    }

    func stop() {
        guard active || pending else { return }
        stopRequested.set(true)
        controller?.stopPictureInPicture()
    }

    /// Playback + mix never interrupts the audio the user is listening to.
    func armAutoStart() async {
        guard let controller, !autoStartArmed else { return }
        do { try await session.acquire("pip") } catch { fail(error)
            return
        }
        autoStartArmed = true
        playing = true
        playbackFlag.set(true)
        renderer?.setPlaying(true)
        controller.invalidatePlaybackState()
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        log.event("pip_auto_start_armed", ["possible": "\(controller.isPictureInPicturePossible)"])
    }

    func disarmAutoStart() {
        guard autoStartArmed else { return }
        autoStartArmed = false
        controller?.canStartPictureInPictureAutomaticallyFromInline = false
        if !active {
            session.release("pip")
        }
        log.event("pip_auto_start_disarmed")
    }

    func handleInterruption(began: Bool, mayResume: Bool) {
        if began {
            playbackFlag.set(false)
            renderer?.setPlaying(false)
            if active {
                state = "PiP interrupted"
            }
        } else {
            if !mayResume {
                playing = false
            }
            playbackFlag.set(playing)
            renderer?.setPlaying(playing)
            if active {
                state = playing ? "PiP active" : "PiP paused — resume from controls"
            }
        }
        controller?.invalidatePlaybackState()
        log.event("pip_session_interruption", ["began": "\(began)", "may_resume": "\(mayResume)"])
    }

    func render(subtitle: String, second: String? = nil, detail: String?) async {
        guard playing, !rendering, let renderer else { return }
        guard renderer.synchronizer.rate > 0 else {
            log.event("subtitle_clock_paused")
            return // Do not queue future timestamps against a stopped render clock.
        }
        rendering = true
        defer { rendering = false }
        do {
            if try await renderer.render(subtitle: subtitle, second: second, detail: detail) {
                let now = ProcessInfo.processInfo.systemUptime
                log.event("subtitle_frame", ["frame": "\(renderer.frames)", "pts": "\(renderer.lastPTS.seconds)",
                                             "active": "\(active)", "gap": lastFrameUptime.map { "\(now - $0)" } ?? "none",
                                             "subtitle": subtitle, "detail": detail ?? "",
                                             "synchronizer_rate": "\(renderer.synchronizer.rate)", "enqueue": "accepted"])
                frames = renderer.frames
                lastFrameUptime = now
            } else {
                log.event("subtitle_backpressure")
            }
        } catch { fail(error) }
    }

    func finishRestore() {
        guard restoreRequested, UIApplication.shared.applicationState == .active else { return }
        restoreRequested = false
        let completion = restoreCompletion
        restoreCompletion = nil
        log.event("pip_restore_completed")
        completion?(true)
    }

    private func fail(_ error: Error) {
        self.error = String(describing: error)
        state = "PiP error"
        log.event("pip_error", ["error": "\(error)"])
    }

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.log.event("pip_will_start") }
    }
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.pending = false
            self.active = true
            self.state = "PiP active"
            self.log.event("pip_did_start")
        }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in self.pending = false
            self.active = false
            self.fail(error)
            self.session.release("pip")
        }
    }
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.log.event("pip_will_stop") }
    }
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        let closed = !returningToApp.get() && !stopRequested.get()
        returningToApp.set(false)
        stopRequested.set(false)
        Task { @MainActor in self.pending = false
            self.active = false
            self.state = "PiP stopped"
            self.log.event("pip_did_stop", ["closed_by_user": "\(closed)"])
            if !self.autoStartArmed {
                self.session.release("pip")
            }
            if closed, UIApplication.shared.applicationState != .active { // Coming back to Hearvia also stops PiP.
                self.onClose?()
            }
        }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        returningToApp.set(true)
        let box = RestoreCompletion(completionHandler)
        Task { @MainActor in
            self.restoreCompletion?(false)
            self.restoreCompletion = box.action
            self.restoreRequested = true
            self.log.event("pip_restore_requested")
        }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        playbackFlag.set(playing)
        Task { @MainActor in
            self.playing = playing
            self.renderer?.setPlaying(playing)
            self.controller?.invalidatePlaybackState()
            self.log.event("pip_set_playing", ["value": "\(playing)"])
        }
    }
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        !playbackFlag.get()
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        Task { @MainActor in
            self.renderSize = "\(newRenderSize.width) × \(newRenderSize.height) px"
            self.log.event("pip_render_size", ["width": "\(newRenderSize.width)", "height": "\(newRenderSize.height)"])
        }
    }
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping () -> Void) {
        // Live content has no seekable history. Complete the request to keep system controls responsive.
        completion()
    }
}

/// AVKit may call the playback delegate outside the main actor.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    init(_ value: Bool) {
        self.value = value
    }
    func set(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.value = value
    }
    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Transferred once to the main actor, where restoration invokes the completion exactly once.
private final class RestoreCompletion: @unchecked Sendable {
    let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) {
        self.action = action
    }
}
