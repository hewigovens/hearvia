import AVFoundation

/// Ordering is preserved by the single AsyncStream consumer.
public final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var resampler = PCM16Resampler()
    private var continuation: AsyncStream<Data>.Continuation?

    private var openingChunks: [Data]?

    public init() {}

    /// Capture may deliver its first buffers before its async start returns.
    public func prepareForCapture() {
        lock.withLock {
            guard continuation == nil else { return }
            openingChunks = []
            resampler = PCM16Resampler()
        }
    }

    public func discardOpeningAudio() {
        lock.withLock {
            guard openingChunks != nil else { return }
            openingChunks = nil
            resampler = PCM16Resampler()
        }
    }

    public func open() -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(150)) // 30 s backlog cap
        lock.withLock { self.continuation?.finish()
            self.continuation = continuation
            if let openingChunks {
                for chunk in openingChunks {
                    continuation.yield(chunk)
                }
                self.openingChunks = nil
            } else {
                resampler = PCM16Resampler()
            }
        }
        return stream
    }

    public func close() {
        lock.withLock { continuation?.finish()
            continuation = nil
            openingChunks = nil
        }
    }

    public func push(_ pcm: AVAudioPCMBuffer) {
        lock.withLock {
            guard continuation != nil || openingChunks != nil else { return }
            for chunk in (try? resampler.append(pcm)) ?? [] {
                if let continuation {
                    continuation.yield(chunk)
                } else {
                    if openingChunks?.count == 5 {
                        openingChunks?.removeFirst()
                    }
                    openingChunks?.append(chunk)
                }
            }
        }
    }
}
