import AVFoundation
import HearviaAudio
import Speech

/// One local recognizer for standby. Audio timestamps share the continuous clock used when Listen is pressed.
@MainActor
public final class WarmCaptions {
    private let speech: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let input: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    public let receive: @Sendable (AVAudioPCMBuffer) -> Void
    private var window = WarmCaptionWindow()
    private let clock = ContinuousClock.now

    public let language: String

    public init(language request: String) async throws {
        let language = request.isEmpty ? await OnDeviceModels.autoCandidates().first : request
        guard let language else { throw OnDeviceError.noSpeechModels }
        self.language = language
        let speech = try await OnDeviceModels.transcriber(language, timed: true)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [speech]) {
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()
        self.speech = speech
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [speech]) else {
            throw AVAudioConverter.ConversionError.unsupported
        }
        analyzer = SpeechAnalyzer(modules: [speech])
        let (stream, input) = AsyncThrowingStream<AnalyzerInput, Error>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.input = input
        let sink = WarmAudioInput(format: format, input: input, clock: clock)
        receive = { sink.push($0) }
        try await analyzer.start(inputSequence: stream)
    }

    public func run() async throws {
        let expiry = Task {
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(200))
                window.expire(now: clock.elapsedSeconds)
            }
        }
        defer { expiry.cancel() }
        var finalizedThrough = -Double.infinity
        for try await result in speech.results {
            try Task.checkCancellation()
            let now = clock.elapsedSeconds
            let words = result.text.runs.compactMap { run -> WarmCaptionWindow.Word? in
                guard let time = run.audioTimeRange else { return nil }
                return .init(text: String(result.text[run.range].characters), start: time.start.seconds, end: time.end.seconds)
            }
            window.replace(from: result.range.start.seconds, with: words, now: now)
            // Long volatile results can have just one timestamp. Finalizing supplies word-level times.
            if !result.isFinal, result.range.duration.seconds >= 3, result.range.end.seconds - finalizedThrough >= 3 {
                finalizedThrough = result.range.end.seconds
                try await analyzer.finalize(through: result.range.end)
            }
        }
    }

    public func snapshot() -> String {
        window.expire(now: clock.elapsedSeconds)
        return window.words.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func close() async {
        input.finish()
        window = WarmCaptionWindow()
        await analyzer.cancelAndFinishNow()
    }
}

struct WarmCaptionWindow {
    struct Word {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
    }

    private(set) var words: [Word] = []

    mutating func expire(now: TimeInterval) {
        words.removeAll { $0.start < now - 5 }
    }

    mutating func replace(from start: TimeInterval, with replacement: [Word], now: TimeInterval) {
        words.removeAll { $0.end > start }
        words.append(contentsOf: replacement)
        expire(now: now)
    }
}

/// Each capture source invokes its sink on one serial queue. Convert before the capture buffer is reused.
private final class WarmAudioInput: @unchecked Sendable {
    private let format: AVAudioFormat
    private let input: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    private let clock: ContinuousClock.Instant
    private var converter: AVAudioConverter?
    private var timeline = WarmAudioTimeline()

    init(format: AVAudioFormat, input: AsyncThrowingStream<AnalyzerInput, Error>.Continuation, clock: ContinuousClock.Instant) {
        self.format = format
        self.input = input
        self.clock = clock
    }

    func push(_ buffer: AVAudioPCMBuffer) {
        do {
            if converter?.inputFormat != buffer.format {
                converter = AVAudioConverter(from: buffer.format, to: format)
            }
            guard let converter else { throw AVAudioConverter.ConversionError.unsupported }
            let output = try converter.convert(buffer)
            guard output.frameLength > 0 else { return }
            let duration = CMTime(value: Int64(output.frameLength), timescale: Int32(format.sampleRate))
            let measured = max(.zero, CMTime(seconds: clock.elapsedSeconds, preferredTimescale: 48000) - duration)
            guard let start = timeline.append(measured: measured, duration: duration) else { return }
            input.yield(AnalyzerInput(buffer: output, bufferStartTime: start))
        } catch { input.finish(throwing: error) }
    }
}

struct WarmAudioTimeline {
    private var end: CMTime?

    mutating func append(measured: CMTime, duration: CMTime) -> CMTime? {
        // Drop a burst buffer if it would start at or after its arrival time.
        if let end, end >= measured + duration {
            return nil
        }
        let start = end.flatMap { (measured - $0).seconds < 0.1 ? $0 : nil } ?? measured
        end = start + duration
        return start
    }
}

private extension ContinuousClock.Instant {
    var elapsedSeconds: Double {
        let elapsed = duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }
}
