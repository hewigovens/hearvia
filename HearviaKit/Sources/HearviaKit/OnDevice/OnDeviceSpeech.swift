import AVFoundation
import Speech

/// One transcription update: the in-progress (volatile) text, or a finished segment.
struct SpeechResult: Sendable {
    let text: String
    let isFinal: Bool
}

/// SpeechAnalyzer fed with the shared 24 kHz PCM16 chunks. `append` must be called from one task at a time.
final class OnDeviceSpeech: @unchecked Sendable {
    let results: AsyncThrowingStream<SpeechResult, Error>
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let converter: AnalyzerInputConverter
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: PCM16Resampler.sampleRate, channels: 1, interleaved: true)!
    private let reader: Task<Void, Never>

    init(language: String, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        try await OnDeviceModels.downloadSpeech(language, progress: progress)
        let transcriber = try await OnDeviceModels.transcriber(language)
        converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        self.input = input
        analyzer = SpeechAnalyzer(modules: [transcriber])
        let (results, output) = AsyncThrowingStream<SpeechResult, Error>.makeStream()
        self.results = results
        reader = Task {
            do {
                for try await result in transcriber.results {
                    output.yield(SpeechResult(text: String(result.text.characters), isFinal: result.isFinal))
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
