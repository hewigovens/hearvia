import Foundation
import HearviaKit
import Observation

/// User preferences owned by the Mac shell; translation languages and engine live on `LiveTranslator`.
@MainActor @Observable
final class AppSettings {
    private enum Keys {
        static let appearance = "hearvia.appearance"
        static let overlayVisible = "hearvia.overlayVisible"
        static let clickThrough = "hearvia.clickThrough"
        static let showsOriginal = "hearvia.showsOriginal"
        static let overlayFontSize = "hearvia.overlayFontSize"
        static let overlayOpacity = "hearvia.overlayOpacity"
    }

    static let overlayFontSizeRange: ClosedRange<Double> = 16 ... 64

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var overlayVisible: Bool {
        didSet { defaults.set(overlayVisible, forKey: Keys.overlayVisible) }
    }

    /// The overlay ignores the mouse so clicks reach the video underneath; it can't be dragged meanwhile.
    var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: Keys.clickThrough) }
    }

    var showsOriginal: Bool {
        didSet { defaults.set(showsOriginal, forKey: Keys.showsOriginal) }
    }

    var overlayFontSize: Double {
        didSet { defaults.set(overlayFontSize, forKey: Keys.overlayFontSize) }
    }

    var overlayOpacity: Double {
        didSet { defaults.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init) ?? .dark
        overlayVisible = defaults.object(forKey: Keys.overlayVisible) as? Bool ?? true
        clickThrough = defaults.bool(forKey: Keys.clickThrough)
        showsOriginal = defaults.object(forKey: Keys.showsOriginal) as? Bool ?? true
        overlayFontSize = defaults.object(forKey: Keys.overlayFontSize) as? Double ?? 30
        overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.65
    }
}
