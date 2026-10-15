import AVFoundation
import UIKit

enum RenderError: Error { case pixelBuffer(OSStatus), context, format(OSStatus), sample(OSStatus), enqueue(String) }

@MainActor
final class SubtitleRenderer {
    let layer: AVSampleBufferDisplayLayer
    let synchronizer = AVSampleBufferRenderSynchronizer()
    private let receiver: AVSampleBufferVideoRenderer.Receiver
    var timebase: CMTimebase { synchronizer.timebase }
    private(set) var lastPTS = CMTime.invalid
    private(set) var frames = 0
    /// User text size, 0.8–1.3; the frame size is fixed so larger text shows fewer lines.
    var fontScale = 1.0
    /// A wide 3:1 frame makes the PiP window a slim subtitle bar rather than a 16:9 video tile.
    static let aspectRatio = 3.0
    private let width = 720
    private let height = 240

    init(layer: AVSampleBufferDisplayLayer) throws {
        self.layer = layer
        receiver = synchronizer.sampleBufferReceiver(adding: layer.sampleBufferRenderer)
        synchronizer.delaysRateChangeUntilHasSufficientMediaData = false
        synchronizer.setRate(1, time: .zero)
        layer.videoGravity = .resizeAspect
    }

    func setPlaying(_ playing: Bool) { synchronizer.setRate(playing ? 1 : 0, time: .invalid) }

    /// A new rasterized frame and valid timed sample are generated every tick; no prerecorded media.
    @discardableResult
    func render(subtitle: String, original: String? = nil, detail: String?) async throws -> Bool {
        var pixel: CVPixelBuffer?
        let pixelStatus = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                        [kCVPixelBufferCGImageCompatibilityKey: true,
                                         kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                                         kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixel)
        guard pixelStatus == kCVReturnSuccess, let pixel else { throw RenderError.pixelBuffer(pixelStatus) }
        CVPixelBufferLockBaseAddress(pixel, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(pixel, [])
            throw RenderError.context
        }
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        let style = NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byWordWrapping
        let bilingual = !(original ?? "").isEmpty
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: (bilingual ? 36 : 40) * fontScale, weight: .semibold),
                                                         .foregroundColor: UIColor.white, .paragraphStyle: style]
        var box = detail == nil ? CGRect(x: 20, y: 12, width: width - 40, height: height - 24)
                                : CGRect(x: 20, y: 8, width: width - 40, height: height - 52)
        if let original, bilingual {
            // Original speech on top (two small grey lines), translation below.
            let originalAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24 * fontScale, weight: .regular),
                                                                     .foregroundColor: UIColor(white: 0.62, alpha: 1),
                                                                     .paragraphStyle: style]
            let top = CGRect(x: box.minX, y: box.minY, width: box.width, height: ceil(62 * fontScale))
            let originalShown = Self.fittingTail(original, attributes: originalAttributes, size: top.size)
            let used = (originalShown as NSString).boundingRect(with: top.size, options: .usesLineFragmentOrigin,
                                                                attributes: originalAttributes, context: nil)
            (originalShown as NSString).draw(in: top.offsetBy(dx: 0, dy: max(0, top.height - ceil(used.height))),
                                             withAttributes: originalAttributes)
            box = CGRect(x: box.minX, y: top.maxY + 6, width: box.width, height: box.height - top.height - 6)
        }
        let shown = Self.fittingTail(subtitle, attributes: attributes, size: box.size)
        let used = (shown as NSString).boundingRect(with: box.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        (shown as NSString).draw(in: box.offsetBy(dx: 0, dy: max(0, box.height - ceil(used.height))), withAttributes: attributes)
        (detail as NSString?)?.draw(in: CGRect(x: 20, y: CGFloat(height) - 38, width: CGFloat(width) - 40, height: 32),
                                 withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium),
                                                  .foregroundColor: UIColor.systemYellow, .paragraphStyle: style])
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var description: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                                        imageBuffer: pixel, formatDescriptionOut: &description)
        guard formatStatus == noErr, let description else { throw RenderError.format(formatStatus) }
        var pts = CMTimeAdd(CMTimebaseGetTime(timebase), CMTime(value: 1, timescale: 30))
        if lastPTS.isValid && CMTimeCompare(pts, lastPTS) <= 0 { pts = CMTimeAdd(lastPTS, CMTime(value: 1, timescale: 30)) }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1),
                                       presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                                     imageBuffer: pixel, formatDescription: description,
                                                                     sampleTiming: &timing, sampleBufferOut: &sample)
        guard sampleStatus == noErr, let sample else { throw RenderError.sample(sampleStatus) }
        let ready = CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(unsafeBuffer: sample)
        var result = try await receiver.enqueue(ready)
        if case .cancelledDueToFlushRequiredToResume = result {
            receiver.flush()
            result = try await receiver.enqueue(ready)
        }
        switch result {
        case .enqueued: break
        case .cancelledDueToFlush: return false
        case .enqueuedWithDecodeFailures(let failures): throw RenderError.enqueue("Decode failures: \(failures)")
        case .cancelledDueToError(let error), .cancelledDueToFlushRequiredToResume(let error): throw error
        @unknown default: throw RenderError.enqueue("Unknown enqueue result")
        }
        lastPTS = pts; frames += 1
        return true
    }

    /// Longest suffix of `text` that fits, starting at a word or CJK character boundary,
    /// so live subtitles scroll upward as translation deltas append.
    static func fittingTail(_ text: String, attributes: [NSAttributedString.Key: Any], size: CGSize) -> String {
        func fits(_ s: Substring) -> Bool {
            (String(s) as NSString).boundingRect(with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
                                                 options: .usesLineFragmentOrigin, attributes: attributes, context: nil).height <= size.height
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if fits(trimmed[...]) { return trimmed }
        var low = 0, high = trimmed.count // binary search on dropped characters
        while low < high {
            let mid = (low + high) / 2
            if fits(trimmed.dropFirst(mid)) { high = mid } else { low = mid + 1 }
        }
        var tail = trimmed.dropFirst(low)
        if let first = tail.first, first.isLetter, first.isASCII, let space = tail.firstIndex(of: " ") {
            tail = tail[tail.index(after: space)...] // avoid starting mid-word for spaced scripts
        }
        return String(tail)
    }
}
