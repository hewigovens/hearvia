import AVFoundation

/// Peak level since the last read, written from the audio queue.
public final class LevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0

    public init() {}

    public func measure(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        var p: Float = 0
        for c in 0 ..< Int(buffer.format.channelCount) where !buffer.format.isInterleaved || c == 0 {
            let count = Int(buffer.frameLength) * (buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1)
            for i in 0 ..< count {
                p = max(p, abs(data[c][i]))
            }
        }
        lock.withLock { peak = max(peak, p) }
    }

    public func take() -> Float {
        lock.withLock { defer { peak = 0 }
            return peak
        }
    }
}
