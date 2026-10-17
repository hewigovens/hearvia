import AVFoundation

/// Ordering is preserved by the single AsyncStream consumer.
public final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var resampler = PCM16Resampler()
    private var continuation: AsyncStream<Data>.Continuation?

    public init() {}

    public func open() -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(150)) // 30 s backlog cap
        lock.withLock { self.continuation?.finish()
            self.continuation = continuation
            resampler = PCM16Resampler()
        }
        return stream
    }

    public func close() {
        lock.withLock { continuation?.finish()
            continuation = nil
        }
    }

    public func push(_ pcm: AVAudioPCMBuffer) {
        lock.withLock {
            guard let continuation else { return }
            for chunk in (try? resampler.append(pcm)) ?? [] {
                continuation.yield(chunk)
            }
        }
    }
}
