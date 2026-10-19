import HearviaAudio
import HearviaCore
import HearviaSession
import SwiftUI

@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let log: DiagnosticLog
    let session: AudioSessionController
    let capture: CaptureController
    let pip: PiPController
    let translation: LiveTranslator
    var audio = ProbeSnapshot()
    var scene = "active"
    var tickCount = 0
    var listening: Bool {
        capture.running || micRunning || demo
    }
    /// App Store screenshot mode (see LiveTranslator+Demo).
    var demo = false
    var listeningSince: Date?
    var micRunning = false
    var micStarting = false
    var micError = ""
    var levels = [Float](repeating: 0, count: 10)

    // MARK: Developer tools

    var translationEnabled = true
    var diagnosticsInPiP = false
    var statusLineInPiP = false
    var observationSource = "Safari"
    var observationNote = ""

    @ObservationIgnored let microphone = MicrophoneCapture()
    @ObservationIgnored let meter = LevelMeter()
    @ObservationIgnored var levelTimer: Timer?
    @ObservationIgnored var wasListening = false
    @ObservationIgnored var renderQueued = false
    @ObservationIgnored private var ticking = false
    @ObservationIgnored private var timer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        RetiredFiles.remove()
        let log = DiagnosticLog()
        self.log = log
        session = AudioSessionController(log: log)
        capture = CaptureController(log: log, session: session)
        pip = PiPController(log: log, session: session)
        translation = LiveTranslator(fallbackKeys: [.realtime: DevSecrets.openAIKey, .gemini: DevSecrets.geminiKey])
        capture.probe.translationFeed = translation.feed
        capture.probe.levelMeter = meter
        if let label = ProcessInfo.processInfo.environment["HEARVIA_EXPERIMENT"] {
            observationSource = label
        }
        session.onInterruption = { [weak pip] began, resume in
            pip?.handleInterruption(began: began, mayResume: resume)
        }
        log.event("environment", ["device": UIDevice.current.model, "os": UIDevice.current.systemVersion,
                                  "os_build": ProcessInfo.processInfo.operatingSystemVersionString,
                                  "app": Bundle.main.bundleIdentifier ?? "unknown", "experiment": observationSource])
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        translation.onTextChange = { [weak self] in self?.scheduleRender() }
        translation.onLog = { [log] name, fields in log.event(name, fields) }
        pip.onClose = { [weak self] in Task { await self?.stopListening() } }
        followShowsOriginal()
        #if DEBUG
            if LiveTranslator.demoRequested {
                demo = true
                wasListening = true
                listeningSince = .now.addingTimeInterval(-754)
                levels = [0.2, 0.5, 0.35, 0.7, 0.45, 0.6, 0.3, 0.55, 0.4, 0.65]
                translation.loadDemo()
                scheduleRender()
            }
        #endif
    }

    private func followShowsOriginal() {
        let shows = withObservationTracking {
            settings.needsOriginal
        } onChange: { [weak self] in
            Task { @MainActor in self?.followShowsOriginal() }
        }
        Task { await translation.setTranscribesSource(shows) }
    }

    func tick() async {
        guard !ticking else { return }
        ticking = true
        defer { ticking = false }
        audio = await capture.probe.read()
        tickCount += 1
        await syncListeningState()
        await renderSubtitle()
        pip.finishRestore()
    }

    func sceneChanged(_ phase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = phase == .active
        scene = phase == .active ? "active" : phase == .background ? "background" : "inactive"
        log.event("scene", ["phase": scene, "pip_active": "\(pip.active)", "capture_running": "\(capture.running)"])
        if phase == .background {
            capture.probe.markBackground(true)
            translation.saveTranscript() // iOS may end a backgrounded app without warning.
        }
        if phase == .active {
            capture.probe.markBackground(false)
            pip.finishRestore()
        }
    }
}
