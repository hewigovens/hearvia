import AVFoundation
import Observation

enum SessionMode: String, CaseIterable, Identifiable {
    case playbackMix = "Playback + mix"
    case recordMix = "Play & record + mix"
    case playbackExclusive = "Playback exclusive"
    var id: String { rawValue }
}

@MainActor @Observable
final class AudioSessionController {
    var mode = SessionMode.playbackMix
    var status = "Inactive"
    var route = ""
    var tonePlaying = false
    var toneStarting = false
    var error = ""
    var onInterruption: ((Bool, Bool) -> Void)?
    private let log: DiagnosticLog
    private var tokens: [NSObjectProtocol] = []
    private var tone: AVAudioPlayer?
    private var owners: Set<String> = []
    private var microphoneOwners: Set<String> = []
    private var operation: Task<Void, Never>?

    init(log: DiagnosticLog) {
        self.log = log
        updateRoute()
        for name in [AVAudioSession.routeChangeNotification, AVAudioSession.didBecomeInactiveNotification,
                     AVAudioSession.resumptionRecommendationNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let fields = ["notification": note.name.rawValue, "info": String(describing: note.userInfo)]
                let deactivation = note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext
                let resumption = note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.log.event("audio_session_notification", fields)
                    self.updateRoute()
                    if name == AVAudioSession.didBecomeInactiveNotification {
                        self.status = deactivation?.source == .system ? "Interrupted by system" : "Inactive"
                        self.onInterruption?(true, false)
                    } else if name == AVAudioSession.resumptionRecommendationNotification {
                        let resume = resumption?.recommendation == .shouldResume
                        if resume && !self.owners.isEmpty { try? await self.activate() }
                        self.onInterruption?(false, resume)
                    }
                }
            })
        }
    }

    func acquire(_ owner: String, microphone: Bool = false) async throws {
        if microphone { mode = .recordMix; microphoneOwners.insert(owner) }
        owners.insert(owner)
        do { try await activate() } catch { owners.remove(owner); microphoneOwners.remove(owner); throw error }
    }

    func activate() async throws {
        let requestedMode = mode
        try await serialize { try await self.performActivation(requestedMode) }
    }

    private func performActivation(_ requestedMode: SessionMode) async throws {
        let session = AVAudioSession.sharedInstance()
        do {
            switch requestedMode {
            case .playbackMix: try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            // Speaker/A2DP output keeps the user's other audio where it was; input stays on the built-in mic.
            case .recordMix: try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            case .playbackExclusive: try session.setCategory(.playback, mode: .default)
            }
            guard try await session.activate(options: []) else { throw NSError(domain: "Hearvia", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio session activation was declined."]) }
            status = requestedMode.rawValue; error = ""; updateRoute()
            log.event("audio_session_active", ["mode": requestedMode.rawValue, "route": route, "sample_rate": "\(session.sampleRate)", "output_volume": "\(session.outputVolume)"])
        } catch { self.error = error.localizedDescription; log.event("audio_session_error", ["error": "\(error)"]); throw error }
    }

    func release(_ owner: String) {
        guard owners.remove(owner) != nil else { return }
        if microphoneOwners.remove(owner) != nil, microphoneOwners.isEmpty {
            mode = .playbackMix // Leave play-and-record so the mic indicator goes away.
            if !owners.isEmpty { Task { try? await self.activate() } }
        }
        if owners.isEmpty { Task { await self.deactivate(onlyIfUnowned: true) } }
    }

    func deactivate(onlyIfUnowned: Bool = false) async {
        do {
            try await serialize {
                if onlyIfUnowned && !self.owners.isEmpty { return }
                guard try await AVAudioSession.sharedInstance().deactivate(options: [.notifyOthersOnDeactivation]) else {
                    throw NSError(domain: "Hearvia", code: 3, userInfo: [NSLocalizedDescriptionKey: "Audio session deactivation was declined."])
                }
                self.status = "Inactive"; self.updateRoute()
                self.log.event("audio_session_inactive", ["owners": self.owners.sorted().joined(separator: ",")])
            }
        } catch { self.error = error.localizedDescription; log.event("audio_session_error", ["error": "\(error)"]) }
    }

    func startTone() async {
        guard !tonePlaying, !toneStarting else { return }
        toneStarting = true
        defer { toneStarting = false }
        do {
            try await acquire("tone")
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
            buffer.frameLength = 48000
            for n in 0..<48000 { buffer.floatChannelData![0][n] = Float(0.1 * sin(2 * .pi * 1000 * Double(n) / 48000)) }
            let url = URL.temporaryDirectory.appending(path: "hearvia-1khz.caf")
            var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: format.settings)
            try file?.write(from: buffer); file = nil
            tone = try AVAudioPlayer(contentsOf: url)
            tone?.numberOfLoops = -1
            guard tone?.play() == true else { throw PCMError.converter }
            tonePlaying = true
            log.event("tone_started", ["hz": "1000", "pcm_peak": "0.1", "pcm_rms": "0.0707107", "mode": mode.rawValue])
        } catch { self.error = error.localizedDescription; log.event("tone_error", ["error": "\(error)"]); release("tone") }
    }

    func stopTone() { tone?.stop(); tone = nil; tonePlaying = false; log.event("tone_stopped"); release("tone") }

    private func serialize(_ action: @escaping @MainActor () async throws -> Void) async throws {
        let previous = operation
        let next = Task { @MainActor in
            await previous?.value
            try await action()
        }
        operation = Task { _ = try? await next.value }
        try await next.value
    }

    private func updateRoute() {
        let s = AVAudioSession.sharedInstance()
        route = (s.currentRoute.inputs + s.currentRoute.outputs).map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
    }
}
