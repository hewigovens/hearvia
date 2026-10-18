import Foundation

public enum EngineKind: String, CaseIterable, Identifiable, Sendable, Codable {
    case onDevice
    case realtime
    case gemini
    case local

    public var id: String {
        rawValue
    }
    public var title: String {
        switch self {
        case .onDevice: String(localized: "On-device")
        case .realtime: "OpenAI Realtime"
        case .gemini: "Gemini Live"
        case .local: String(localized: "Local LLM")
        }
    }
    /// For tiles and one-line summaries, where the full name would wrap.
    public var shortTitle: String {
        switch self {
        case .realtime: "OpenAI"
        case .gemini: "Gemini"
        default: title
        }
    }
    public var tagline: String {
        switch self {
        case .onDevice: String(localized: "Free · private · works offline")
        case .realtime: String(localized: "Fastest · best quality · ~$2/hour")
        case .gemini: String(localized: "Free to try · ~$2.20/hour after")
        case .local: String(localized: "Experimental · your Ollama, LM Studio or Unsloth")
        }
    }
    public var isCloud: Bool {
        self == .realtime || self == .gemini
    }
    /// The cloud models detect the spoken language; the on-device engine needs it chosen.
    public var detectsSpokenLanguage: Bool {
        isCloud
    }
    public var keyAccount: String? {
        switch self {
        case .onDevice: nil
        case .realtime: "openai-api-key"
        case .gemini: "gemini-api-key"
        case .local: "local-model-api-key"
        }
    }
}
