import AVFoundation
import UIKit

enum RenderError: Error { case pixelBuffer(OSStatus), context, format(OSStatus), sample(OSStatus), enqueue(String) }

@MainActor
final class SubtitleRenderer {
    let layer: AVSampleBufferDisplayLayer
    let synchronizer = AVSampleBufferRenderSynchronizer()
    private let receiver: AVSampleBufferVideoRenderer.Receiver
    var timebase: CMTimebase {
        synchronizer.timebase
    }
    private(set) var lastPTS = CMTime.invalid
    private(set) var frames = 0
    /// User text size, 0.8–1.3; the frame size is fixed so larger text shows fewer lines.
    var fontScale = 1.0
    /// A wide 3:1 frame makes the PiP window a slim subtitle bar rather than a 16:9 video tile.
    static let aspectRatio = 3.0
    let width = 720
    let height = 240

    init(layer: AVSampleBufferDisplayLayer) throws {
        self.layer = layer
        receiver = synchronizer.sampleBufferReceiver(adding: layer.sampleBufferRenderer)
        synchronizer.delaysRateChangeUntilHasSufficientMediaData = false
        synchronizer.setRate(1, time: .zero)
        layer.videoGravity = .resizeAspect
    }

    func setPlaying(_ playing: Bool) {
        synchronizer.setRate(playing ? 1 : 0, time: .invalid)
    }

    /// A new rasterized frame and valid timed sample are generated every tick; no prerecorded media.
    @discardableResult
    func render(subtitle: String, original: String? = nil, detail: String?) async throws -> Bool {
        let pixel = try makePixelBuffer()
        try draw(subtitle: subtitle, original: original, detail: detail, scale: fontScale, into: pixel)
        var pts = CMTimeAdd(CMTimebaseGetTime(timebase), CMTime(value: 1, timescale: 30))
        if lastPTS.isValid, CMTimeCompare(pts, lastPTS) <= 0 {
            pts = CMTimeAdd(lastPTS, CMTime(value: 1, timescale: 30))
        }
        let ready = try CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(unsafeBuffer: Self.makeSample(pixel, at: pts))
        var result = try await receiver.enqueue(ready)
        if case .cancelledDueToFlushRequiredToResume = result {
            receiver.flush()
            result = try await receiver.enqueue(ready)
        }
        switch result {
        case .enqueued: break
        case .cancelledDueToFlush: return false // The next tick renders a fresh frame.
        case let .enqueuedWithDecodeFailures(failures): throw RenderError.enqueue("Decode failures: \(failures)")
        case let .cancelledDueToError(error), let .cancelledDueToFlushRequiredToResume(error): throw error
        @unknown default: throw RenderError.enqueue("Unknown enqueue result")
        }
        lastPTS = pts
        frames += 1
        return true
    }

    nonisolated private static func makeSample(_ pixel: CVPixelBuffer, at pts: CMTime) throws -> CMSampleBuffer {
        var description: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                        imageBuffer: pixel, formatDescriptionOut: &description)
        guard formatStatus == noErr, let description else { throw RenderError.format(formatStatus) }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1),
                                        presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                                    imageBuffer: pixel, formatDescription: description,
                                                                    sampleTiming: &timing, sampleBufferOut: &sample)
        guard sampleStatus == noErr, let sample else { throw RenderError.sample(sampleStatus) }
        return sample
    }
}
