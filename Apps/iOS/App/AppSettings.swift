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
        static let subtitleScale = "hearvia.subtitleScale"
        static let floatsWhenLeaving = "hearvia.floatsWhenLeaving"
        static let hasCompletedOnboarding = "hearvia.hasCompletedOnboarding"
    }

    static let subtitleScaleRange: ClosedRange<Double> = 0.8 ... 1.3

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var input: InputSource {
        didSet { defaults.set(input.rawValue, forKey: Keys.input) }
    }

    var showsOriginal: Bool {
        didSet { defaults.set(showsOriginal, forKey: Keys.showsOriginal) }
    }

    /// The PiP frame is fixed, so larger text shows fewer lines.
    var subtitleScale: Double {
        didSet { defaults.set(subtitleScale, forKey: Keys.subtitleScale) }
    }

    var floatsWhenLeaving: Bool {
        didSet { defaults.set(floatsWhenLeaving, forKey: Keys.floatsWhenLeaving) }
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
        subtitleScale = defaults.object(forKey: Keys.subtitleScale) as? Double ?? 1
        floatsWhenLeaving = defaults.object(forKey: Keys.floatsWhenLeaving) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}
