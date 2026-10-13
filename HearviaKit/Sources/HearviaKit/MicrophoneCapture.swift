import AVFoundation

public struct MicrophoneError: LocalizedError {
    public var errorDescription: String? { "Microphone access is off. Allow it in Settings → Privacy & Security → Microphone." }
}

/// Raw microphone input (no voice processing, so nearby speech and loudspeaker sound are kept).
/// On iOS the caller activates a play-and-record AVAudioSession first.
public final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    public private(set) var running = false

    public init() {}

    public func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        guard !running else { return }
        guard await AVAudioApplication.requestRecordPermission() else { throw MicrophoneError() }
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 4_800, format: input.outputFormat(forBus: 0)) { buffer, _ in onBuffer(buffer) }
        do { try engine.start() } catch { input.removeTap(onBus: 0); throw error }
        running = true
    }

    public func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}

/// Peak level since the last read, written from the audio queue.
public final class LevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0

    public init() {}

    public func measure(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        var p: Float = 0
        for c in 0..<Int(buffer.format.channelCount) where !buffer.format.isInterleaved || c == 0 {
            let count = Int(buffer.frameLength) * (buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1)
            for i in 0..<count { p = max(p, abs(data[c][i])) }
        }
        lock.withLock { peak = max(peak, p) }
    }

    public func take() -> Float { lock.withLock { defer { peak = 0 }; return peak } }
}
