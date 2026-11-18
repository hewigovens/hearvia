import AVFoundation
@testable import HearviaAudio
import Testing

@Test func openingAudioJoinsLiveAudioInOrder() async throws {
    let feed = AudioFeed()
    let reference = AudioFeed()
    let uninterrupted = reference.open()
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: PCM16Resampler.outputFormat, frameCapacity: 4800))
    buffer.frameLength = 4800
    func push(_ sample: Int16) {
        buffer.int16ChannelData![0].update(repeating: sample, count: 4800)
        reference.push(buffer)
        feed.push(buffer)
    }
    feed.prepareForCapture()
    for value in 1 ... 7 {
        push(Int16(value * 1000))
    }
    let audio = feed.open()
    push(8000)
    feed.close()
    reference.close()
    var expected: [Data] = []
    for await chunk in uninterrupted {
        expected.append(chunk)
    }
    var received: [Data] = []
    for await chunk in audio {
        received.append(chunk)
    }
    #expect(received.count == 6)
    #expect(received == Array(expected.suffix(6)))

    feed.prepareForCapture()
    feed.push(buffer)
    feed.push(buffer)
    feed.discardOpeningAudio()
    let restarted = feed.open()
    feed.close()
    var iterator = restarted.makeAsyncIterator()
    #expect(await iterator.next() == nil)
}
