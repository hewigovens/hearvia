import AVFoundation

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
        // The tap delivers read-only buffers; the feed and level meter take AVAudioPCMBuffer, so hand them a copy.
        try input.installAudioTap(onBus: 0, bufferSize: 4800, format: input.outputFormat(forBus: 0)) { buffer, _ in
            onBuffer(AVAudioPCMBuffer(copying: buffer))
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
