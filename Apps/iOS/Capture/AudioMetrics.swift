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
