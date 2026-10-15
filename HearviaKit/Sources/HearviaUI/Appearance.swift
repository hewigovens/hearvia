import SwiftUI

/// App-wide color scheme choice. Dark is the default: the app is mostly used next to video.
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case dark, light, system
    public var id: String {
        rawValue
    }
    public var title: String {
        rawValue.capitalized
    }
    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
