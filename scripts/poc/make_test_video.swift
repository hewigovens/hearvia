// Host-only deterministic HTML5 video fixture. This is source media for Safari,
// not the subtitle renderer and not bundled with the app.
import AVFoundation
import CoreGraphics
import Foundation

@main
enum MakeTestVideo {
    static func main() async throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                                                                        AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                                                        AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2,
                                                                        AVEncoderBitRateKey: 128000])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes:
                                                            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                                             kCVPixelBufferWidthKey as String: 320,
                                                             kCVPixelBufferHeightKey as String: 180])
        writer.add(video); writer.add(audio)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        for second in 0..<2 {
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
            pcm.frameLength = 48000
            let hz = second == 0 ? 440.0 : 880.0
            for c in 0..<2 { for n in 0..<48000 { pcm.floatChannelData![c][n] = Float(0.1 * sin(2 * .pi * hz * Double(n) / 48000)) } }
            var description: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: format.streamDescription, layoutSize: 0,
                                           layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil,
                                           formatDescriptionOut: &description)
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000),
                                           presentationTimeStamp: CMTime(value: Int64(second), timescale: 1), decodeTimeStamp: .invalid)
            var sample: CMSampleBuffer?
            CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: true, makeDataReadyCallback: nil,
                                 refcon: nil, formatDescription: description, sampleCount: 48000, sampleTimingEntryCount: 1,
                                 sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample)
            CMSampleBufferSetDataBufferFromAudioBufferList(sample!, blockBufferAllocator: kCFAllocatorDefault,
                                                         blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcm.audioBufferList)
            while !audio.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            guard audio.append(sample!) else { throw writer.error! }
            for frame in 0..<6 {
                var pixel: CVPixelBuffer?
                CVPixelBufferCreate(kCFAllocatorDefault, 320, 180, kCVPixelFormatType_32BGRA, nil, &pixel)
                CVPixelBufferLockBaseAddress(pixel!, [])
                let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel!), width: 320, height: 180,
                                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel!),
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
                context.setFillColor(CGColor(red: second == 0 ? 0.1 : 0.6, green: 0.2, blue: 0.5, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
                CVPixelBufferUnlockBaseAddress(pixel!, [])
                while !video.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
                guard adaptor.append(pixel!, withPresentationTime: CMTime(value: Int64(second * 6 + frame), timescale: 6)) else { throw writer.error! }
            }
        }
        audio.markAsFinished(); video.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error! }
        print(url.path)
    }
}
