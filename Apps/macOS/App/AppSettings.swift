import AppKit
import HearviaSession
import HearviaUI
import Observation

@MainActor @Observable
final class AppSettings {
    private enum Keys {
        static let appearance = "hearvia.appearance"
        static let overlayVisible = "hearvia.overlayVisible"
        static let clickThrough = "hearvia.clickThrough"
        static let showsOriginal = "hearvia.showsOriginal"
        static let originalLarge = "hearvia.originalLarge"
        static let twoLines = "hearvia.twoLines"
        static let overlayFontSize = "hearvia.overlayFontSize"
        static let overlayOpacity = "hearvia.overlayOpacity"
        static let menuBarOnly = "hearvia.menuBarOnly"
        static let hasExplainedPermissions = "hearvia.hasExplainedPermissions"
    }

    static let overlayFontSizeRange: ClosedRange<Double> = 16 ... 64

    var appearance: Appearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    var overlayVisible: Bool {
        didSet { defaults.set(overlayVisible, forKey: Keys.overlayVisible) }
    }

    /// The overlay ignores the mouse so clicks reach the video underneath; it can't be dragged meanwhile.
    var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: Keys.clickThrough) }
    }

    /// Shows the smaller second line: the original speech, or the translation while `originalLarge`.
    var showsOriginal: Bool {
        didSet { defaults.set(showsOriginal, forKey: Keys.showsOriginal) }
    }

    /// The original speech in large text, for following the speaker rather than the translation.
    var originalLarge: Bool {
        didSet { defaults.set(originalLarge, forKey: Keys.originalLarge) }
    }

    /// The original is billed separately by OpenAI Realtime, so it's only requested while shown or while transcripts are saved.
    var needsOriginal: Bool {
        showsOriginal || originalLarge
    }

    /// The large text keeps its newest two lines, like film subtitles; off, it fills the overlay with more of what was said.
    var twoLines: Bool {
        didSet { defaults.set(twoLines, forKey: Keys.twoLines) }
    }

    var overlayFontSize: Double {
        didSet { defaults.set(overlayFontSize, forKey: Keys.overlayFontSize) }
    }

    var overlayOpacity: Double {
        didSet { defaults.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }

    var menuBarOnly: Bool {
        didSet {
            defaults.set(menuBarOnly, forKey: Keys.menuBarOnly)
            applyActivationPolicy()
            if !menuBarOnly {
                NSApp.activate() // Puts the returning Dock icon and menu bar in front.
            }
        }
    }

    var hasExplainedPermissions: Bool {
        didSet { defaults.set(hasExplainedPermissions, forKey: Keys.hasExplainedPermissions) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init) ?? .dark
        overlayVisible = defaults.object(forKey: Keys.overlayVisible) as? Bool ?? true
        clickThrough = defaults.bool(forKey: Keys.clickThrough)
        showsOriginal = defaults.object(forKey: Keys.showsOriginal) as? Bool ?? true
        originalLarge = defaults.bool(forKey: Keys.originalLarge)
        twoLines = defaults.object(forKey: Keys.twoLines) as? Bool ?? true
        overlayFontSize = defaults.object(forKey: Keys.overlayFontSize) as? Double ?? 30
        overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.65
        menuBarOnly = defaults.bool(forKey: Keys.menuBarOnly)
        hasExplainedPermissions = defaults.bool(forKey: Keys.hasExplainedPermissions)
    }

    /// App-wide, so the menu bar popover and the overlay panel match the windows: the palette's dynamic colors resolve against each window's AppKit appearance, which `preferredColorScheme` doesn't reach in the popover.
    func applyAppearance() {
        NSApp.appearance = switch appearance {
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        case .system: nil
        }
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }
}
