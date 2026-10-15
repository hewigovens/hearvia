import AVFoundation
@testable import HearviaKit
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

@Test func parsesTranslationEvents() {
    let delta = #"{"type":"session.output_transcript.delta","delta":"你好","elapsed_ms":1200}"#
    guard case let .translationDelta(text, ms) = RealtimeTranslationClient.parse(Data(delta.utf8)) else { Issue.record()
        return
    }
    #expect(text == "你好" && ms == 1200)
    let error = #"{"type":"error","error":{"type":"invalid_request_error","code":"invalid_event","message":"bad"}}"#
    guard case let .serverError(_, code, message) = RealtimeTranslationClient.parse(Data(error.utf8)) else { Issue.record()
        return
    }
    #expect(code == "invalid_event" && message == "bad")
}
