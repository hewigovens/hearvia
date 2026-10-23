import Foundation
import HearviaSession
import HearviaUI
import Observation

@MainActor @Observable
final class AppSettings {
    private enum Keys {
        static let appearance = "hearvia.appearance"
        static let input = "hearvia.input"
        static let showsOriginal = "hearvia.showsOriginal"
        static let originalLarge = "hearvia.originalLarge"
        static let subtitleScale = "hearvia.subtitleScale"
        static let floatsWhenLeaving = "hearvia.floatsWhenLeaving"
        static let autoStopMinutes = "hearvia.autoStopMinutes"
        static let hasCompletedOnboarding = "hearvia.hasCompletedOnboarding"
    }

    static let subtitleScaleRange: ClosedRange<Double> = 0.8 ... 1.3

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var input: InputSource {
        didSet { defaults.set(input.rawValue, forKey: Keys.input) }
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

    /// The PiP frame is fixed, so larger text shows fewer lines.
    var subtitleScale: Double {
        didSet { defaults.set(subtitleScale, forKey: Keys.subtitleScale) }
    }

    var floatsWhenLeaving: Bool {
        didSet { defaults.set(floatsWhenLeaving, forKey: Keys.floatsWhenLeaving) }
    }

    /// Minutes after which a cloud session stops by itself, since those bill per connected minute; 0 is off.
    var autoStopMinutes: Int {
        didSet { defaults.set(autoStopMinutes, forKey: Keys.autoStopMinutes) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init) ?? .dark
        input = defaults.string(forKey: Keys.input).flatMap(InputSource.init) ?? .otherApps
        showsOriginal = defaults.object(forKey: Keys.showsOriginal) as? Bool ?? true
        originalLarge = defaults.bool(forKey: Keys.originalLarge)
        subtitleScale = defaults.object(forKey: Keys.subtitleScale) as? Double ?? 1
        autoStopMinutes = defaults.integer(forKey: Keys.autoStopMinutes)
        floatsWhenLeaving = defaults.object(forKey: Keys.floatsWhenLeaving) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}
