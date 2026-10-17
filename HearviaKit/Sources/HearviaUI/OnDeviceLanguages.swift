import HearviaCore
import HearviaEngines
import Observation

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

    /// "" is Auto-detect, offered first where Hearvia recognizes speech itself.
    public func spokenChoices(for engine: EngineKind, including selected: String) -> [String] {
        let choices = Languages.choices(for: engine, onDevice: spoken, including: selected).filter { !$0.isEmpty }
        return engine.detectsSpokenLanguage ? choices : [""] + choices
    }

    /// A local model isn't limited to Apple's translation languages.
    public func subtitleChoices(for engine: EngineKind, including selected: String) -> [String] {
        Languages.choices(for: engine, onDevice: engine == .onDevice ? subtitles : [], including: selected)
    }
}
