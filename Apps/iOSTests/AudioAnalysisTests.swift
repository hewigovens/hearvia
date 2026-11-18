import AVFoundation
@testable import Hearvia
import XCTest

final class AudioAnalysisTests: XCTestCase {
    func testSilenceDoesNotPassSignalCheck() throws {
        let pcm = try XCTUnwrap(try AVAudioPCMBuffer(pcmFormat: XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)), frameCapacity: 4800))
        pcm.frameLength = 4800
        for c in 0 ..< 2 {
            for n in 0 ..< 4800 {
                pcm.floatChannelData?[c][n] = 0
            }
        }
        let stats = AudioMetrics.measure(pcm)
        XCTAssertEqual(stats.rms, 0)
        XCTAssertEqual(stats.peak, 0)
        XCTAssertEqual(stats.nonZeroPercent, 0)
        XCTAssertEqual(stats.toneEnergyFraction, 0)
    }

    func testPhaseIndependentToneEvidence() throws {
        let pcm = try XCTUnwrap(try AVAudioPCMBuffer(pcmFormat: XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)), frameCapacity: 4800))
        pcm.frameLength = 4800
        for c in 0 ..< 2 {
            for n in 0 ..< 4800 {
                pcm.floatChannelData?[c][n] = Float(0.1 * sin(2 * .pi * 1000 * Double(n) / 48000 + Double(c)))
            }
        }
        let stats = AudioMetrics.measure(pcm)
        XCTAssertEqual(stats.rms, 0.1 / sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(stats.toneAmplitude, 0.1, accuracy: 1e-6)
        XCTAssertGreaterThan(stats.toneEnergyFraction, 0.99)
        XCTAssertGreaterThan(stats.nonZeroPercent, 90)
    }

    func testOtherFrequencyIsNotClassifiedAsOwnTone() throws {
        let pcm = try XCTUnwrap(try AVAudioPCMBuffer(pcmFormat: XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)), frameCapacity: 4800))
        pcm.frameLength = 4800
        for n in 0 ..< 4800 {
            pcm.floatChannelData?[0][n] = Float(0.1 * sin(2 * .pi * 440 * Double(n) / 48000))
        }
        let stats = AudioMetrics.measure(pcm)
        XCTAssertGreaterThan(stats.rms, 0.07)
        XCTAssertLessThan(stats.toneAmplitude, 1e-6)
    }

    func testCoreMediaInterleavedInt16PCMIsCopiedAndNormalized() throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 2, interleaved: true))
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800))
        input.frameLength = 4800
        let data = try XCTUnwrap(input.int16ChannelData?[0])
        for n in 0 ..< 4800 {
            data[2 * n] = Int16(3276 * sin(2 * .pi * 1000 * Double(n) / 48000))
            data[2 * n + 1] = 0
        }
        var description: CMAudioFormatDescription?
        XCTAssertEqual(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: format.streamDescription,
                                                      layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                                                      extensions: nil, formatDescriptionOut: &description), noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: true,
                                            makeDataReadyCallback: nil, refcon: nil, formatDescription: description,
                                            sampleCount: 4800, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample), noErr)
        let wrapped = try XCTUnwrap(sample)
        XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(wrapped, blockBufferAllocator: kCFAllocatorDefault,
                                                                      blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                                      flags: 0, bufferList: input.audioBufferList), noErr)
        let output = try PCMDecoder.decode(wrapped)
        XCTAssertFalse(output.format.isInterleaved)
        XCTAssertEqual(output.frameLength, 4800)
        XCTAssertEqual(output.format.channelCount, 2)
        XCTAssertEqual(try XCTUnwrap(output.floatChannelData?[0][12]), 0.1, accuracy: 0.0001)
        XCTAssertEqual(output.floatChannelData?[1][12], 0)
        XCTAssertEqual(AudioMetrics.measure(output).rms, 0.05, accuracy: 0.0001)
    }
}
