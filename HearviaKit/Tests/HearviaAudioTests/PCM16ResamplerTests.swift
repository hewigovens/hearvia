import AVFoundation
@testable import HearviaAudio
import Testing

@Test func resamples48kStereoFloatTo200msChunks() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
    let resampler = PCM16Resampler()
    var chunks: [Data] = []
    for _ in 0 ..< 50 { // 50 × 960 frames = 1 s, the typical ScreenCaptureKit buffer size
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960))
        buffer.frameLength = 960
        for c in 0 ..< 2 {
            for n in 0 ..< 960 {
                buffer.floatChannelData?[c][n] = 0.5
            }
        }
        chunks += try resampler.append(buffer)
    }
    #expect(chunks.count >= 4) // converter latency may hold back part of the last chunk
    #expect(chunks.allSatisfy { $0.count == 9600 })
    let last = try #require(chunks.last?.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) })
    #expect(abs(Int(last[2000]) - 16384) < 200) // DC 0.5 survives downmix at full scale
}
