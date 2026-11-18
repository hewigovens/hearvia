import SwiftUI

/// Dark is the default: the app is mostly used next to video.
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case dark, light, system
    public var id: String {
        rawValue
    }
    public var title: String {
        switch self {
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        case .system: String(localized: "System")
        }
    }
    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
    public var symbol: String {
        switch self {
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        case .system: "circle.lefthalf.filled"
        }
    }
}
