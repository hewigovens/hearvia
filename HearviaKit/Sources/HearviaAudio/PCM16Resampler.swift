import AVFoundation

/// Not thread-safe: call from one serial queue.
public final class PCM16Resampler {
    public static let sampleRate = 24000.0
    public static let chunkFrames = 4800 // 200 ms
    public static let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate,
                                                   channels: 1, interleaved: true)!

    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var pending = Data()

    public init() {}

    public func append(_ buffer: AVAudioPCMBuffer) throws -> [Data] {
        guard buffer.frameLength > 0 else { return [] }
        if inputFormat != buffer.format {
            guard let c = AVAudioConverter(from: buffer.format, to: Self.outputFormat) else { throw AVAudioConverter.ConversionError.unsupported }
            c.downmix = true // average channels rather than taking the left one
            converter = c
            inputFormat = buffer.format
        }
        guard let converter else { throw AVAudioConverter.ConversionError.unsupported }
        let out = try converter.convert(buffer)
        if out.frameLength > 0, let samples = out.int16ChannelData {
            pending.append(UnsafeBufferPointer(start: samples[0], count: Int(out.frameLength)))
        }
        return drain()
    }

    /// Zero-filled chunk; `hearvia-translate` ends a file with a few seconds of it so the model can finish.
    public static var silenceChunk: Data {
        Data(count: chunkFrames * 2)
    }

    /// Chunks and the remainder get their own storage: slicing `Data` keeps the whole buffer alive and growing.
    private func drain() -> [Data] {
        let bytes = Self.chunkFrames * 2
        let count = pending.count / bytes
        guard count > 0 else { return [] }
        let start = pending.startIndex
        let chunks = (0 ..< count).map { Data(pending[start + $0 * bytes ..< start + ($0 + 1) * bytes]) }
        pending = Data(pending[(start + count * bytes)...])
        return chunks
    }
}
