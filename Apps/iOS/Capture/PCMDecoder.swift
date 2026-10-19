import AVFoundation
import CoreMedia

enum PCMError: Error { case invalidFormat, allocation, copy(OSStatus), converter }

enum PCMDecoder {
    /// Copy, rather than retain borrowed AudioBufferList pointers past the callback. CoreMedia handles planar/interleaved layout; AVAudioConverter normalizes integer/float PCM.
    static func decode(_ sample: CMSampleBuffer) throws -> AVAudioPCMBuffer {
        guard CMSampleBufferIsValid(sample), CMSampleBufferDataIsReady(sample),
              let description = CMSampleBufferGetFormatDescription(sample),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              asbd.pointee.mFormatID == kAudioFormatLinearPCM,
              let format = AVAudioFormat(streamDescription: asbd) else { throw PCMError.invalidFormat }
        let count = CMSampleBufferGetNumSamples(sample)
        guard count > 0, count <= Int(Int32.max),
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            throw PCMError.allocation
        }
        input.frameLength = AVAudioFrameCount(count)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count),
                                                                  into: input.mutableAudioBufferList)
        guard status == noErr else { throw PCMError.copy(status) }
        guard let target = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate,
                                         channels: format.channelCount),
            let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: input.frameLength),
            let converter = AVAudioConverter(from: format, to: target) else { throw PCMError.converter }
        try converter.convert(to: output, from: input)
        return output
    }
}
