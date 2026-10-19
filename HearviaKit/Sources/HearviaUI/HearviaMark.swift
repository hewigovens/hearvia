import SwiftUI

/// Drawn on a 100-unit grid; scripts/make_icons.swift draws the app icon with the same geometry.
public struct HearviaMark: View {
    private static let bars: [CGRect] = [CGRect(x: 15, y: 40, width: 6, height: 20), CGRect(x: 25, y: 29, width: 6, height: 42),
                                         CGRect(x: 35, y: 35, width: 6, height: 30)]
    private static let translationLine = CGRect(x: 47, y: 38, width: 38, height: 9)
    private static let originalLine = CGRect(x: 47, y: 53, width: 26, height: 9)

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            func rect(_ r: CGRect) -> Path {
                Path(roundedRect: CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale),
                     cornerRadius: r.width.isLess(than: 10) ? r.width * scale / 2 : r.height * scale / 2)
            }
            let accent = Color(hex: 0x8B9CFF)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x141733)))
            for bar in Self.bars {
                context.fill(rect(bar), with: .color(accent))
            }
            context.fill(rect(Self.translationLine), with: .color(accent))
            context.fill(rect(Self.originalLine), with: .color(.white.opacity(0.55)))
        }
    }
}
