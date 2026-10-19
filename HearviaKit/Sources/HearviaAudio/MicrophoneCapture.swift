import AVFoundation

/// No voice processing, so nearby speech and loudspeaker sound are kept. On iOS the caller activates a play-and-record AVAudioSession first.
public final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private(set) var running = false

    public init() {}

    public func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        guard !running else { return }
        guard await AVAudioApplication.requestRecordPermission() else { throw MicrophoneError() }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Tap buffers are only valid inside the callback, so the feed and level meter get a copy.
        if #available(macOS 27, *) {
            try input.installAudioTap(onBus: 0, bufferSize: 4800, format: format) { buffer, _ in
                onBuffer(AVAudioPCMBuffer(copying: buffer))
            }
        } else {
            input.installTap(onBus: 0, bufferSize: 4800, format: format) { buffer, _ in
                if let copy = buffer.copy() {
                    onBuffer(copy)
                }
            }
        }
        do { try engine.start() } catch { input.removeTap(onBus: 0)
            throw error
        }
        running = true
    }

    public func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}

private extension AVAudioPCMBuffer {
    func copy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            guard let bytes = from.mData else { continue }
            to.mData?.copyMemory(from: bytes, byteCount: Int(min(from.mDataByteSize, to.mDataByteSize)))
        }
        return copy
    }
}
