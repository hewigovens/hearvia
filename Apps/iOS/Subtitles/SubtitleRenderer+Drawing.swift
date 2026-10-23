import UIKit

extension SubtitleRenderer {
    nonisolated func makePixelBuffer() throws -> CVPixelBuffer {
        var pixel: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                         [kCVPixelBufferCGImageCompatibilityKey: true,
                                          kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                                          kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixel)
        guard status == kCVReturnSuccess, let pixel else { throw RenderError.pixelBuffer(status) }
        return pixel
    }

    /// Nonisolated so the pixel buffer stays in a disconnected region and can be sent to the renderer.
    nonisolated func draw(subtitle: String, second: String?, detail: String?, scale: Double, into pixel: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(pixel, [])
        defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            throw RenderError.context
        }
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        let bilingual = !(second ?? "").isEmpty
        var box = detail == nil ? CGRect(x: 28, y: 20, width: width - 56, height: height - 40)
            : CGRect(x: 28, y: 12, width: width - 56, height: height - 60)
        if let second, bilingual {
            let top = CGRect(x: box.minX, y: box.minY, width: box.width, height: ceil(84 * scale))
            Self.drawTail(second, attributes: Self.attributes(size: 32 * scale, weight: .medium, color: UIColor(white: 0.72, alpha: 1)), in: top)
            box = CGRect(x: box.minX, y: top.maxY + 10, width: box.width, height: box.height - top.height - 10)
        }
        Self.drawTail(subtitle, attributes: Self.attributes(size: (bilingual ? 48 : 50) * scale, weight: .semibold, color: .white), in: box)
        if let detail {
            (detail as NSString).draw(in: CGRect(x: 20, y: CGFloat(height) - 38, width: CGFloat(width) - 40, height: 32),
                                      withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium),
                                                       .foregroundColor: UIColor.systemYellow, .paragraphStyle: Self.centered])
        }
    }

    nonisolated private static func attributes(size: CGFloat, weight: UIFont.Weight, color: UIColor) -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: centered]
    }

    nonisolated private static func drawTail(_ text: String, attributes: [NSAttributedString.Key: Any], in box: CGRect) {
        let shown = Self.fittingTail(text, attributes: attributes, size: box.size) as NSString
        let used = shown.boundingRect(with: box.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        shown.draw(in: box.offsetBy(dx: 0, dy: max(0, box.height - ceil(used.height))), withAttributes: attributes)
    }

    nonisolated(unsafe) private static let centered: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        return style
    }()

    /// Starts at a word or CJK character boundary so live subtitles scroll upward as translation deltas append.
    nonisolated static func fittingTail(_ text: String, attributes: [NSAttributedString.Key: Any], size: CGSize) -> String {
        func fits(_ s: Substring) -> Bool {
            (String(s) as NSString).boundingRect(with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
                                                 options: .usesLineFragmentOrigin, attributes: attributes, context: nil).height <= size.height
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if fits(trimmed[...]) {
            return trimmed
        }
        var low = 0, high = trimmed.count
        while low < high {
            let mid = (low + high) / 2
            if fits(trimmed.dropFirst(mid)) {
                high = mid
            } else {
                low = mid + 1
            }
        }
        var tail = trimmed.dropFirst(low)
        if let first = tail.first, first.isLetter, first.isASCII, let space = tail.firstIndex(of: " ") {
            tail = tail[tail.index(after: space)...] // avoid starting mid-word for spaced scripts
        }
        return String(tail)
    }
}
