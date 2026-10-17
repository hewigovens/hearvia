import AVFoundation
import HearviaAudio
import ScreenCaptureKit

/// All mutable state belongs to this serial queue, including the SCStreamOutput callback.
final class AudioProbe: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "dev.hewig.hearvia.pcm", qos: .userInitiated)
    /// Set once at launch, before any capture callback.
    var translationFeed: AudioFeed?
    var levelMeter: LevelMeter?
    private let log: DiagnosticLog
    private var snapshot = ProbeSnapshot()
    private var lastPTS: [Int: Double] = [:]
    private var lastLog: [Int: Double] = [:]
    private var backgroundStart: Double?
    private var backgroundLast: [Int: Double] = [:]
    private var file: AVAudioFile?
    private var recordingSource = SCStreamOutputType.audio
    private var framesWritten: AVAudioFrameCount = 0
    private var recordingFormat: AVAudioFormat?
    private var recordingArmed = false
    private var activeStream: ObjectIdentifier?

    init(log: DiagnosticLog) {
        self.log = log
    }

    func reset() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.finishRecordingOnQueue()
                self.snapshot = ProbeSnapshot()
                self.activeStream = nil
                self.lastPTS = [:]
                self.lastLog = [:]
                self.backgroundLast = [:]
                continuation.resume()
            }
        }
    }

    func bind(_ stream: SCStream) async {
        let identity = ObjectIdentifier(stream)
        await withCheckedContinuation { continuation in
            queue.async { self.activeStream = identity
                continuation.resume()
            }
        }
    }

    func unbind() {
        queue.async { self.activeStream = nil
            self.finishRecordingOnQueue()
        }
    }

    func read() async -> ProbeSnapshot {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.snapshot) }
        }
    }

    func markBackground(_ background: Bool) {
        queue.async {
            if background {
                self.backgroundStart = ProcessInfo.processInfo.systemUptime
                self.backgroundLast = [:]
                for source in [SCStreamOutputType.audio, .microphone] {
                    var stats = self.stats(source)
                    stats.backgroundSpan = 0
                    stats.backgroundPCMSeconds = 0
                    stats.backgroundAudibleSeconds = 0
                    stats.backgroundMaxGap = 0
                    self.setStats(stats, source)
                }
            } else {
                self.log.event("background_window_end_system", self.snapshot.system.logFields)
                self.log.event("background_window_end_microphone", self.snapshot.microphone.logFields)
                self.backgroundStart = nil
            }
        }
    }

    func armRecording(microphone: Bool) {
        queue.async {
            self.finishRecordingOnQueue()
            self.recordingSource = microphone ? .microphone : .audio
            self.recordingArmed = true
            self.framesWritten = 0
            self.snapshot.recordingURL = nil
            self.snapshot.recordingState = "Waiting for \(microphone ? "microphone" : "system") PCM"
            self.log.event("recording_armed", ["source": microphone ? "microphone" : "system", "duration": "15"])
        }
    }

    func finishRecording() {
        queue.async { self.finishRecordingOnQueue() }
    }

    private func finishRecordingOnQueue() {
        if recordingArmed {
            snapshot.recordingState = file == nil ? "No PCM received" : "Saved \(framesWritten) frames"
            log.event("recording_finished", ["frames": "\(framesWritten)", "file": snapshot.recordingURL?.lastPathComponent ?? "none"])
        }
        file = nil
        recordingFormat = nil
        recordingArmed = false
    }

    private func stats(_ source: SCStreamOutputType) -> AudioSnapshot {
        source == .audio ? snapshot.system : snapshot.microphone
    }
    private func setStats(_ stats: AudioSnapshot, _ source: SCStreamOutputType) {
        if source == .audio {
            snapshot.system = stats
        } else {
            snapshot.microphone = stats
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard activeStream == ObjectIdentifier(stream) else { return }
        guard type == .audio || type == .microphone else { return } // Screen frames are intentionally discarded.
        do {
            let pcm = try PCMDecoder.decode(sampleBuffer)
            if type == .audio { // before writeRecording, which may shorten frameLength
                translationFeed?.push(pcm)
                levelMeter?.measure(pcm)
            }
            record(pcm, of: type, at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
            if recordingArmed, type == recordingSource {
                try writeRecording(pcm)
            }
        } catch {
            var stats = stats(type)
            stats.errors += 1
            setStats(stats, type)
            // Bound error logging if every buffer has an unsupported format.
            if stats.errors == 1 || stats.errors % 100 == 0 {
                log.event("pcm_error", ["source": "\(type.rawValue)", "error": "\(error)"])
            }
            if recordingArmed, type == recordingSource {
                finishRecordingOnQueue()
                snapshot.recordingState = "Recording failed: \(error)"
            }
        }
    }

    private func record(_ pcm: AVAudioPCMBuffer, of type: SCStreamOutputType, at pts: Double) {
        let metrics = AudioMetrics.measure(pcm)
        let now = ProcessInfo.processInfo.systemUptime
        let duration = Double(pcm.frameLength) / pcm.format.sampleRate
        var stats = stats(type)
        if let last = stats.lastUptime {
            stats.maxGap = max(stats.maxGap, now - last)
        }
        stats.buffers += 1
        stats.seconds += duration
        stats.sampleRate = pcm.format.sampleRate
        stats.channels = Int(pcm.format.channelCount)
        stats.lastUptime = now
        stats.rms = metrics.rms
        stats.peak = metrics.peak
        stats.nonZeroPercent = metrics.nonZeroPercent
        stats.toneAmplitude = metrics.toneAmplitude
        stats.toneEnergyFraction = metrics.toneEnergyFraction
        if metrics.nonZeroPercent == 0 {
            stats.silentBuffers += 1
        }
        if pts.isFinite {
            if let previous = lastPTS[type.rawValue], pts <= previous {
                stats.ptsRegressions += 1
            }
            lastPTS[type.rawValue] = pts
        }
        if let start = backgroundStart {
            stats.backgroundSpan = now - start // Only advances when a PCM callback arrives.
            stats.backgroundPCMSeconds += duration
            if metrics.rms > 0.0001 {
                stats.backgroundAudibleSeconds += duration
            }
            stats.backgroundMaxGap = max(stats.backgroundMaxGap, now - (backgroundLast[type.rawValue] ?? start))
            backgroundLast[type.rawValue] = now
        }
        setStats(stats, type)
        if now - (lastLog[type.rawValue] ?? 0) >= 1 {
            log.event(type == .audio ? "system_pcm" : "microphone_pcm", stats.logFields)
            lastLog[type.rawValue] = now
        }
    }

    private func writeRecording(_ pcm: AVAudioPCMBuffer) throws {
        if file == nil {
            let source = recordingSource == .audio ? "system" : "microphone"
            let url = URL.documentsDirectory.appending(path: "\(source)-\(UUID().uuidString).caf")
            file = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            recordingFormat = pcm.format
            snapshot.recordingURL = url
        }
        guard recordingFormat == pcm.format else {
            finishRecordingOnQueue()
            snapshot.recordingState = "Saved partial: audio format changed"
            return
        }
        let target = AVAudioFrameCount(pcm.format.sampleRate * 15)
        pcm.frameLength = min(pcm.frameLength, target - framesWritten)
        try file?.write(from: pcm)
        framesWritten += pcm.frameLength
        snapshot.recordingState = String(format: "Recording %.1f / 15 s", Double(framesWritten) / pcm.format.sampleRate)
        if framesWritten >= target {
            finishRecordingOnQueue()
        }
    }
}
