import HearviaCore
import HearviaEngines
import Observation

/// The on-device engine's spoken and subtitle languages, read from the system once and shared by every picker.
/// Empty until loaded; `Languages.choices` falls back to the Realtime list meanwhile.
@MainActor @Observable
public final class OnDeviceLanguages {
    public static let shared = OnDeviceLanguages()

    public private(set) var spoken: [String] = []
    public private(set) var subtitles: [String] = []

    private init() {
        Task {
            spoken = await OnDeviceModels.spokenLanguages()
            subtitles = await OnDeviceModels.subtitleLanguages()
        }
    }

    public func spokenChoices(for engine: EngineKind, including selected: String) -> [String] {
        Languages.choices(for: engine, onDevice: spoken, including: selected)
    }

    /// TranslateGemma isn't limited to Apple's translation languages; it gets the shared list.
    public func subtitleChoices(for engine: EngineKind, including selected: String) -> [String] {
        Languages.choices(for: engine, onDevice: engine == .onDevice ? subtitles : [], including: selected)
    }
}
