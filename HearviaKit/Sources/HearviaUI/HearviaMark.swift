import SwiftUI

/// The app icon's mark ("wave to words"), drawn on a 100-unit grid. Also used by the icon generator.
public struct HearviaMark: View {
    public enum Style: Sendable { case standard, dark, tinted }
    let style: Style
    let background: Bool

    public init(style: Style = .standard, background: Bool = true) {
        self.style = style
        self.background = background
    }

    public static let bars: [CGRect] = [CGRect(x: 15, y: 40, width: 6, height: 20), CGRect(x: 25, y: 29, width: 6, height: 42),
                                        CGRect(x: 35, y: 35, width: 6, height: 30)]
    public static let translationLine = CGRect(x: 47, y: 38, width: 38, height: 9)
    public static let originalLine = CGRect(x: 47, y: 53, width: 26, height: 9)

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            func rect(_ r: CGRect) -> Path {
                Path(roundedRect: CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale),
                     cornerRadius: r.width.isLess(than: 10) ? r.width * scale / 2 : r.height * scale / 2)
            }
            let (ground, accent, secondary) = Self.colors(style)
            if background {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ground))
            }
            for bar in Self.bars {
                context.fill(rect(bar), with: .color(accent))
            }
            context.fill(rect(Self.translationLine), with: .color(accent))
            context.fill(rect(Self.originalLine), with: .color(secondary))
        }
    }

    static func colors(_ style: Style) -> (Color, Color, Color) {
        switch style {
        case .standard: (Color(hex: 0x141733), Color(hex: 0x8B9CFF), Color.white.opacity(0.55))
        case .dark: (Color(hex: 0x05060D), Color(hex: 0x8B9CFF), Color(hex: 0x8B9CFF).opacity(0.45))
        case .tinted: (Color.black, Color(white: 0.85), Color(white: 0.85).opacity(0.45))
        }
    }
}
