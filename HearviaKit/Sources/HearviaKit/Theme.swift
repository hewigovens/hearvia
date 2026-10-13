import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// App-wide color scheme choice. Dark is the default: the app is mostly used next to video.
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case dark, light, system
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
    public static let storageKey = "appearance"
}

/// Periwinkle (dark, default) and Paper light palettes from the design canvas.
/// Subtitle surfaces stay dark in both themes.
public extension Color {
    static let hvGround = Color(light: 0xF7F7F5, dark: 0x0E1020)
    static let hvSurface = Color(light: 0xFFFFFF, dark: 0x191C33)
    static let hvSurfaceRaised = Color(light: 0xE9ECF8, dark: 0x262A47)
    static let hvSelected = Color(light: 0xE9ECF8, dark: 0x3E4570)
    static let hvLine = Color(light: 0xDADDE6, dark: 0x2C3150)
    static let hvText = Color(light: 0x15171D, dark: 0xF3F4F6)
    static let hvMuted = Color(light: 0x5B616E, dark: 0xA6ABC8)
    static let hvAccent = Color(light: 0x2F5BFF, dark: 0x8B9CFF)
    static let hvOnAccent = Color(light: 0xFFFFFF, dark: 0x0B1033)
    static let hvAccentSoft = Color(light: 0xEEF2FF, dark: 0x1A1E3A)
    static let hvReady = Color(light: 0x1E9E62, dark: 0x4CC38A)
    static let hvStop = Color(hex: 0xC8352E)
    static let hvSubtitleGround = Color(hex: 0x000000)
    static let hvSubtitleOriginal = Color(hex: 0x8A919E)

    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif

/// The app icon's mark ("wave to words"), drawn on a 100-unit grid. Also used by the icon generator.
public struct HearviaMark: View {
    public enum Style: Sendable { case standard, dark, tinted }
    let style: Style
    let background: Bool

    public init(style: Style = .standard, background: Bool = true) { self.style = style; self.background = background }

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
            if background { context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ground)) }
            for bar in Self.bars { context.fill(rect(bar), with: .color(accent)) }
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

/// App icon tile with the iOS continuous-corner mask.
public struct HearviaIcon: View {
    let size: CGFloat
    public init(size: CGFloat) { self.size = size }
    public var body: some View {
        HearviaMark()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Filled pill button: accent for primary actions, red for Stop, raised surface for secondary ones.
public struct HVButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, stop, secondary }
    let kind: Kind
    let height: CGFloat
    public init(_ kind: Kind = .primary, height: CGFloat = 56) { self.kind = kind; self.height = height }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height >= 50 ? 18 : 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(kind == .primary ? Color.hvOnAccent : kind == .stop ? .white : Color.hvText)
            .background(kind == .primary ? Color.hvAccent : kind == .stop ? Color.hvStop : Color.hvSurface,
                        in: .rect(cornerRadius: height >= 50 ? 18 : 14, style: .continuous))
            .overlay {
                if kind == .secondary { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.hvLine) }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}

/// Recent input levels as a short bar meter, newest on the right.
public struct LevelBars: View {
    let levels: [Float]
    public init(levels: [Float]) { self.levels = levels }
    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule().fill(Color.hvAccent)
                    .frame(width: 4, height: max(3, CGFloat(min(1, sqrt(level) * 1.4)) * 24))
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityLabel("Input level")
    }
}

/// Pill segmented control in the Hearvia palette (system segmented controls ignore the tint on macOS).
public struct SegmentedChoice<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: KeyPath<Option, String>
    let symbol: (Option) -> String
    var height: CGFloat = 44

    public init(selection: Binding<Option>, options: [Option], title: KeyPath<Option, String>,
                height: CGFloat = 44, symbol: @escaping (Option) -> String) {
        _selection = selection; self.options = options; self.title = title; self.height = height; self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    Label(option[keyPath: title], systemImage: symbol(option))
                        .font(.system(size: height >= 40 ? 15 : 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.hvText : Color.hvMuted)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(selected ? Color.hvSelected : .clear, in: .rect(cornerRadius: height >= 40 ? 10 : 6, style: .continuous))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(height >= 40 ? 4 : 2)
        .background(Color.hvSurface, in: .rect(cornerRadius: height >= 40 ? 14 : 8, style: .continuous))
    }
}

