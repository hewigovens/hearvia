import AVFoundation
import HearviaAudio
import Speech

final class OnDeviceSpeech: SpeechInput, @unchecked Sendable {
    let results: AsyncThrowingStream<SpeechResult, Error>
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let convert: (AVAudioPCMBuffer) throws -> [AnalyzerInput]
    private let reader: Task<Void, Never>

    convenience init(language: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        try await OnDeviceModels.downloadSpeech(language, progress: progress)
        try await self.init(transcribers: [OnDeviceModels.transcriber(language)], languages: [language])
    }

    /// Auto: recognizes with each installed candidate until one is clearly right (see +Detection).
    static func detecting(_ languages: [String]) async throws -> OnDeviceSpeech {
        guard !languages.isEmpty else { throw OnDeviceError.noSpeechModels }
        var transcribers: [SpeechTranscriber] = []
        for language in languages {
            try await transcribers.append(OnDeviceModels.transcriber(language, confidence: true))
        }
        return try await OnDeviceSpeech(transcribers: transcribers, languages: languages)
    }

    private init(transcribers: [SpeechTranscriber], languages: [String]) async throws {
        if #available(macOS 27, *) {
            let converter = try await AnalyzerInputConverter.converter(compatibleWith: transcribers)
            convert = { try converter.convert($0, at: nil) }
        } else {
            guard let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: transcribers),
                  let converter = AVAudioConverter(from: PCM16Resampler.outputFormat, to: target)
            else { throw AVAudioConverter.ConversionError.unsupported }
            convert = { buffer in
                let out = try converter.convert(buffer)
                return out.frameLength > 0 ? [AnalyzerInput(buffer: out)] : []
            }
        }
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        self.input = input
        let analyzer = SpeechAnalyzer(modules: transcribers)
        self.analyzer = analyzer
        let (results, output) = AsyncThrowingStream<SpeechResult, Error>.makeStream()
        self.results = results
        // Detection reads the recognizers back from the analyzer rather than holding them, so the losers are freed once they're removed.
        let single = transcribers.count == 1 ? transcribers[0] : nil
        let names = Dictionary(uniqueKeysWithValues: zip(transcribers.map(ObjectIdentifier.init), languages))
        reader = Task {
            guard let single else {
                await Self.detect(languages: languages, names: names, analyzer: analyzer, output: output)
                return
            }
            do {
                for try await result in single.results {
                    output.yield(SpeechResult(result, language: languages[0]))
                }
                output.finish()
            } catch { output.finish(throwing: error) }
        }
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            reader.cancel()
            throw error
        }
    }

    func append(_ chunk: Data) throws {
        let frames = AVAudioFrameCount(chunk.count / 2)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: PCM16Resampler.outputFormat, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        chunk.withUnsafeBytes { raw in
            buffer.int16ChannelData![0].update(from: raw.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
        }
        for item in try convert(buffer) {
            input.yield(item)
        }
    }

    /// Frees the recognizers right away: a stopped run's last words aren't wanted, and a restart needs the recognizers back.
    func finish() async {
        input.finish()
        await analyzer.cancelAndFinishNow()
        reader.cancel()
    }
}

extension SpeechResult {
    init(_ result: SpeechTranscriber.Result, language: String) {
        self.init(text: String(result.text.characters), isFinal: result.isFinal, language: language)
    }
}
