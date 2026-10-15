import SwiftUI
#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

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
    static let hvAttention = Color(light: 0xC2570C, dark: 0xF5A35C)
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
