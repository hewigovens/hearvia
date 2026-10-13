import AVFoundation

/// Converts arbitrary PCM buffers into the Realtime translation input format
/// (24 kHz, mono, PCM16 little-endian) and emits fixed 200 ms chunks.
/// Not thread-safe: call from one serial queue (the capture queue).
public final class PCM16Resampler {
    public static let sampleRate = 24_000.0
    public static let chunkFrames = 4_800 // 200 ms, the engine's frame size
    public static let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate,
                                                   channels: 1, interleaved: true)!

    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var pending = Data()

    public init() {}

    /// Returns zero or more complete 200 ms chunks.
    public func append(_ buffer: AVAudioPCMBuffer) throws -> [Data] {
        guard buffer.frameLength > 0 else { return [] }
        if inputFormat != buffer.format {
            guard let c = AVAudioConverter(from: buffer.format, to: Self.outputFormat) else { throw ResamplerError.unsupported }
            c.downmix = true // average channels rather than taking the left one
            converter = c; inputFormat = buffer.format
        }
        guard let converter else { throw ResamplerError.unsupported }
        let ratio = Self.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.outputFormat, frameCapacity: capacity) else { throw ResamplerError.allocation }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if consumed { inputStatus.pointee = .noDataNow; return nil }
            consumed = true; inputStatus.pointee = .haveData; return buffer
        }
        if status == .error { throw error ?? ResamplerError.conversion }
        if out.frameLength > 0, let samples = out.int16ChannelData {
            pending.append(UnsafeBufferPointer(start: samples[0], count: Int(out.frameLength)))
        }
        return drain()
    }

    /// Zero-filled chunk to keep the stream contiguous while the source is silent or paused.
    public static var silenceChunk: Data { Data(count: chunkFrames * 2) }

    private func drain() -> [Data] {
        let bytes = Self.chunkFrames * 2
        var chunks: [Data] = []
        while pending.count >= bytes {
            chunks.append(pending.prefix(bytes))
            pending.removeFirst(bytes)
        }
        return chunks
    }

    public enum ResamplerError: Error { case unsupported, allocation, conversion }
}
