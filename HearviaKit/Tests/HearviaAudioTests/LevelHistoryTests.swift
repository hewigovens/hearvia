import AVFoundation
@testable import HearviaAudio
import Testing

@MainActor @Test func levelHistoryKeepsTheNewestPeaksAndClearsOnStop() throws {
    let history = LevelHistory()
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480))
    buffer.frameLength = 480
    buffer.floatChannelData?[0][100] = -0.5
    history.meter.measure(buffer)
    history.sample()
    history.sample() // the meter resets once read
    #expect(history.peaks.count == 10 && history.peaks.suffix(2) == [0.5, 0])
    history.stop()
    #expect(history.peaks.allSatisfy { $0 == 0 })
}
