import AVFoundation
import HearviaAudio
import Speech

final class OnDeviceSpeech: SpeechInput, @unchecked Sendable {
    let results: AsyncThrowingStream<SpeechResult, Error>
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let converter: AnalyzerInputConverter
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: PCM16Resampler.sampleRate, channels: 1, interleaved: true)!
    private let reader: Task<Void, Never>

    convenience init(language: String, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await OnDeviceModels.downloadSpeech(language, progress: progress)
        try await self.init(transcribers: [OnDeviceModels.transcriber(language)], languages: [language])
    }

    /// Auto: recognizes with each installed candidate until one is clearly right (see +Detection).
    convenience init(detecting languages: [String]) async throws {
        guard !languages.isEmpty else { throw OnDeviceError.noSpeechModels }
        var transcribers: [SpeechTranscriber] = []
        for language in languages {
            try await transcribers.append(OnDeviceModels.transcriber(language, confidence: true))
        }
        try await self.init(transcribers: transcribers, languages: languages)
    }

    private init(transcribers: [SpeechTranscriber], languages: [String]) async throws {
        converter = try await AnalyzerInputConverter.converter(compatibleWith: transcribers)
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        self.input = input
        let analyzer = SpeechAnalyzer(modules: transcribers)
        self.analyzer = analyzer
        let (results, output) = AsyncThrowingStream<SpeechResult, Error>.makeStream()
        self.results = results
        reader = Task {
            if transcribers.count > 1 {
                await Self.detect(transcribers, languages: languages, analyzer: analyzer, output: output)
                return
            }
            do {
                for try await result in transcribers[0].results {
                    output.yield(SpeechResult(result, language: languages[0]))
                }
                output.finish()
            } catch { output.finish(throwing: error) }
        }
        try await analyzer.start(inputSequence: stream)
    }

    func append(_ chunk: Data) throws {
        let frames = AVAudioFrameCount(chunk.count / 2)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        chunk.withUnsafeBytes { raw in
            buffer.int16ChannelData![0].update(from: raw.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        for item in try converter.convert(buffer, at: nil) {
            input.yield(item)
        }
    }

    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        reader.cancel()
    }
}
