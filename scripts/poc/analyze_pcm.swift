import AVFoundation
import Foundation

@main
enum AnalyzePCM {
    static func main() throws {
        guard CommandLine.arguments.count > 1 else {
            print("Usage: analyze_pcm FILE.caf [OTHER.caf]")
            return
        }
        var amplitudes: [Double] = []
        for path in CommandLine.arguments.dropFirst() {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path), commonFormat: .pcmFormatFloat32, interleaved: false)
            guard file.length > 0, file.length <= Int64(UInt32.max),
                  let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw PCMError.allocation
            }
            try file.read(into: pcm)
            let m = AudioMetrics.measure(pcm)
            amplitudes.append(m.toneAmplitude)
            let fields: [String: Any] = ["file": URL(fileURLWithPath: path).lastPathComponent,
                                         "frames": pcm.frameLength, "sample_rate": pcm.format.sampleRate,
                                         "channels": pcm.format.channelCount, "seconds": Double(pcm.frameLength) / pcm.format.sampleRate,
                                         "rms": m.rms, "peak": m.peak, "nonzero_pct": m.nonZeroPercent,
                                         "tone_1khz_amplitude": m.toneAmplitude, "tone_energy_fraction": m.toneEnergyFraction]
            try print(String(data: JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]), encoding: .utf8)!)
            let windowFrames = AVAudioFrameCount(pcm.format.sampleRate / 2)
            if let window = AVAudioPCMBuffer(pcmFormat: pcm.format, frameCapacity: windowFrames) {
                for start in stride(from: 0, to: Int(pcm.frameLength), by: Int(windowFrames)) {
                    let count = min(Int(windowFrames), Int(pcm.frameLength) - start)
                    window.frameLength = AVAudioFrameCount(count)
                    for c in 0 ..< Int(pcm.format.channelCount) {
                        window.floatChannelData![c].update(from: pcm.floatChannelData![c].advanced(by: start), count: count)
                    }
                    let m440 = AudioMetrics.measure(window, toneHz: 440)
                    let m880 = AudioMetrics.measure(window, toneHz: 880)
                    let m1000 = AudioMetrics.measure(window)
                    print(String(format: "t=%.1f rms=%.6f a440=%.6f a880=%.6f a1000=%.6f", Double(start) / pcm.format.sampleRate, m1000.rms,
                                 m440.toneAmplitude, m880.toneAmplitude, m1000.toneAmplitude))
                }
            }
        }
        if amplitudes.count == 2, amplitudes[0] > 0 {
            let attenuation = 20 * log10(max(amplitudes[1], 1e-12) / amplitudes[0])
            print("Second/first 1 kHz amplitude: \(attenuation) dB. Use unexcluded first, excluded second; verify identical source/route/volume.")
        }
    }
}
