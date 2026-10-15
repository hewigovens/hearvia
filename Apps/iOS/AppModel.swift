import HearviaKit
import SwiftUI
import Observation

enum InputSource: String, CaseIterable, Identifiable {
    case otherApps, microphone
    var id: String { rawValue }
    var title: String { self == .otherApps ? "Other apps" : "Microphone" }
}

@MainActor @Observable
final class AppModel {
    let log: DiagnosticLog
    let session: AudioSessionController
    let capture: CaptureController
    let pip: PiPController
    let translation: LiveTranslator
    var translationEnabled = true
    var audio = ProbeSnapshot()
    var source = "Safari"
    var note = ""
    var diagnosticsInPiP = false
    var statusLineInPiP = false
    var bilingual = UserDefaults.standard.object(forKey: "bilingual") as? Bool ?? true {
        didSet { UserDefaults.standard.set(bilingual, forKey: "bilingual") }
    }
    var input = UserDefaults.standard.string(forKey: "inputSource").flatMap(InputSource.init) ?? .otherApps {
        didSet { UserDefaults.standard.set(input.rawValue, forKey: "inputSource") }
    }
    /// Start the floating window automatically when the user leaves Hearvia while listening.
    var autoFloat = UserDefaults.standard.object(forKey: "autoFloat") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(autoFloat, forKey: "autoFloat")
            Task { if autoFloat && listening { await pip.armAutoStart() } else if !autoFloat { pip.disarmAutoStart() } }
        }
    }
    var subtitleScale = UserDefaults.standard.object(forKey: "subtitleScale") as? Double ?? 1 {
        didSet { UserDefaults.standard.set(subtitleScale, forKey: "subtitleScale"); pip.fontScale = subtitleScale; scheduleRender() }
    }
    private(set) var listeningSince: Date?
    private(set) var micRunning = false
    private(set) var micStarting = false
    private(set) var micError = ""
    /// Last ~1 s of input peaks (system audio or mic), 10 per second.
    private(set) var levels = [Float](repeating: 0, count: 10)
    var level: Float { levels.last ?? 0 }
    @ObservationIgnored private let microphone = MicrophoneCapture()
    @ObservationIgnored private let meter = LevelMeter()
    @ObservationIgnored private var levelTimer: Timer?
    var listening: Bool { capture.running || micRunning }
    var tickCount = 0
    var scene = "active"
    private var timer: Timer?
    private var reading = false
    private var wasCapturing = false
    private var renderQueued = false

    init() {
        let log = DiagnosticLog()
        self.log = log
        session = AudioSessionController(log: log)
        capture = CaptureController(log: log, session: session)
        pip = PiPController(log: log, session: session)
        translation = LiveTranslator(fallbackKey: DevSecrets.openAIKey)
        capture.probe.translationFeed = translation.feed
        capture.probe.levelMeter = meter
        if let label = ProcessInfo.processInfo.environment["HEARVIA_EXPERIMENT"] { source = label }
        session.onInterruption = { [weak pip] began, resume in
            pip?.handleInterruption(began: began, mayResume: resume)
        }
        log.event("environment", ["device": UIDevice.current.model, "os": UIDevice.current.systemVersion,
                                  "os_build": ProcessInfo.processInfo.operatingSystemVersionString,
                                  "app": Bundle.main.bundleIdentifier ?? "unknown", "experiment": source])
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        pip.fontScale = subtitleScale
        translation.onTextChange = { [weak self] in self?.scheduleRender() }
        translation.onLog = { [log] name, fields in log.event(name, fields) }
    }

    /// Coalesce translation deltas into at most ~5 PiP frames per second.
    private func scheduleRender() {
        guard !renderQueued else { return }
        renderQueued = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            renderQueued = false
            await renderSubtitle()
        }
    }

    private func renderSubtitle() async {
        let elapsed = capture.captureStart.map { ProcessInfo.processInfo.systemUptime - $0 } ?? 0
        let system = audio.system
        let captureLabel = micRunning ? "Microphone" : capture.running ? String(format: "Capture %.0f s", elapsed) : capture.state
        let subtitle: String
        if diagnosticsInPiP {
            subtitle = String(format: "System RMS %.5f\n%@", system.rms, captureLabel)
        } else if !translation.translation.isEmpty {
            subtitle = translation.translation
        } else {
            subtitle = translation.active ? "Listening…" : listening ? "Connecting…" : "Subtitles appear here"
        }
        let lag = translation.lastDeltaUptime.map { String(format: "text %.0fs ago", ProcessInfo.processInfo.systemUptime - $0) } ?? "no text"
        let detail: String? = !statusLineInPiP ? nil : "#\(tickCount) · \(scene) · PCM \(system.age.map { String(format: "%.1fs", $0) } ?? "none") · \(translation.state) · \(lag)"
        let original = bilingual && !diagnosticsInPiP && !translation.translation.isEmpty ? translation.source : nil
        await pip.render(subtitle: subtitle, original: original, detail: detail)
    }

    private func tick() async {
        guard !reading else { return }
        reading = true
        defer { reading = false }
        audio = await capture.probe.read()
        tickCount += 1
        if listening != wasCapturing {
            wasCapturing = listening
            listeningSince = listening ? Date() : nil
            levelTimer?.invalidate(); levelTimer = nil; levels = levels.map { _ in 0 }
            if listening {
                let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                    Task { @MainActor in guard let self else { return }; self.levels = Array(self.levels.dropFirst()) + [self.meter.take()] }
                }
                RunLoop.main.add(timer, forMode: .common); levelTimer = timer
            }
            if listening {
                if autoFloat { await pip.armAutoStart() }
                if translationEnabled { await translation.start() }
            } else {
                pip.disarmAutoStart()
                await translation.stop()
            }
        }
        await renderSubtitle()
        pip.finishRestore()
    }

    func sceneChanged(_ phase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = phase == .active // Keep the measurement controls awake; manual lock still works.
        scene = phase == .active ? "active" : phase == .background ? "background" : "inactive"
        log.event("scene", ["phase": scene, "pip_active": "\(pip.active)", "capture_running": "\(capture.running)"])
        if phase == .background { capture.probe.markBackground(true) }
        if phase == .active { capture.probe.markBackground(false); pip.finishRestore() }
    }

    func startListening() {
        switch input {
        case .otherApps: capture.start()
        case .microphone: Task { await startMicrophone() }
        }
    }

    func stopListening() async {
        if micRunning || micStarting {
            microphone.stop(); micRunning = false
            session.release("mic-input")
            log.event("mic_stopped")
        } else {
            await capture.stop()
        }
        pip.stop()
        await tick() // Stop translation now rather than on the next timer tick.
    }

    private func startMicrophone() async {
        guard !micRunning, !micStarting else { return }
        micStarting = true; micError = ""
        defer { micStarting = false }
        let feed = translation.feed, meter = meter
        do {
            try await session.acquire("mic-input", microphone: true)
            try await microphone.start { buffer in meter.measure(buffer); feed.push(buffer) }
            micRunning = true
            log.event("mic_started", ["route": session.route])
            await tick()
        } catch {
            micError = error.localizedDescription
            session.release("mic-input")
            log.event("mic_error", ["error": "\(error)"])
        }
    }

    func mark() {
        log.event("manual_observation", ["source": source, "note": note,
                                          "exclude_own_audio": "\(capture.excludeOwnAudio)", "mic": "\(capture.microphoneEnabled)",
                                          "tone": "\(session.tonePlaying)", "session": session.status, "pip": pip.state])
        log.sync(); note = ""
    }
}
