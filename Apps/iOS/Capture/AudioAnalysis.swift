import AVFoundation
import CoreMedia

struct AudioMetrics: Sendable {
    let rms: Double
    let peak: Double
    let nonZeroPercent: Double
    let toneAmplitude: Double
    let toneEnergyFraction: Double

    /// The sinusoidal projection is phase independent.
    static func measure(_ pcm: AVAudioPCMBuffer, toneHz: Double = 1000) -> AudioMetrics {
        let frames = Int(pcm.frameLength)
        let channels = Int(pcm.format.channelCount)
        guard frames > 0, let data = pcm.floatChannelData else {
            return AudioMetrics(rms: 0, peak: 0, nonZeroPercent: 0, toneAmplitude: 0, toneEnergyFraction: 0)
        }
        var square = 0.0, peak = 0.0, nonZero = 0
        var tonePower = 0.0
        let step = 2 * Double.pi * toneHz / pcm.format.sampleRate
        for c in 0 ..< channels {
            var sine = 0.0, cosine = 0.0
            for n in 0 ..< frames {
                let x = Double(data[c][n])
                square += x * x
                peak = max(peak, abs(x))
                if abs(x) > 1e-7 {
                    nonZero += 1
                }
                sine += x * sin(step * Double(n))
                cosine += x * cos(step * Double(n))
            }
            tonePower += 4 * (sine * sine + cosine * cosine) / Double(frames * frames)
        }
        let meanSquare = square / Double(frames * channels)
        let amplitude = sqrt(tonePower / Double(channels))
        return AudioMetrics(rms: sqrt(meanSquare), peak: peak,
                            nonZeroPercent: 100 * Double(nonZero) / Double(frames * channels),
                            toneAmplitude: amplitude,
                            toneEnergyFraction: meanSquare > 0 ? min(1, amplitude * amplitude / (2 * meanSquare)) : 0)
    }
}

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

struct AudioSnapshot: Sendable {
    var buffers = 0
    var seconds = 0.0
    var sampleRate = 0.0
    var channels = 0
    var lastUptime: Double?
    var rms = 0.0
    var peak = 0.0
    var nonZeroPercent = 0.0
    var toneAmplitude = 0.0
    var toneEnergyFraction = 0.0
    var silentBuffers = 0
    var maxGap = 0.0
    var ptsRegressions = 0
    var backgroundSpan = 0.0
    var backgroundPCMSeconds = 0.0
    var backgroundAudibleSeconds = 0.0
    var backgroundMaxGap = 0.0
    var errors = 0

    var age: Double? {
        lastUptime.map { ProcessInfo.processInfo.systemUptime - $0 }
    }
    var logFields: [String: String] {
        ["buffers": "\(buffers)", "pcm_seconds": "\(seconds)", "sample_rate": "\(sampleRate)",
         "channels": "\(channels)", "rms": "\(rms)", "peak": "\(peak)", "nonzero_pct": "\(nonZeroPercent)",
         "tone_1khz_amplitude": "\(toneAmplitude)", "tone_energy_fraction": "\(toneEnergyFraction)",
         "silent_buffers": "\(silentBuffers)", "last_buffer_age": age.map { String($0) } ?? "none",
         "max_gap": "\(maxGap)", "pts_regressions": "\(ptsRegressions)",
         "background_span": "\(backgroundSpan)", "background_pcm_seconds": "\(backgroundPCMSeconds)",
         "background_audible_seconds": "\(backgroundAudibleSeconds)", "background_max_gap": "\(backgroundMaxGap)",
         "decode_errors": "\(errors)"]
    }
}
