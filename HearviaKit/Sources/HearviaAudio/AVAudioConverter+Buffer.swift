import AVFoundation

public extension AVAudioConverter {
    /// Feeds one buffer and returns what came out; the converter keeps its resampling state for the next call.
    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw ConversionError.allocation }
        var consumed = false
        var error: NSError?
        let status = convert(to: out, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if status == .error {
            throw error ?? ConversionError.conversion
        }
        return out
    }

    enum ConversionError: Error { case unsupported, allocation, conversion }
}
