import Foundation

/// Which pipeline turns captured audio into subtitles.
public enum EngineKind: String, CaseIterable, Identifiable, Sendable, Codable {
    /// SpeechTranscriber + Translation framework: free, offline, sentence-level lag.
    case onDevice
    /// gpt-realtime-translate over WebSocket: lowest lag, paid per minute.
    case realtime
    /// gemini-3.5-live-translate over the Live API: free tier for testing, paid per minute after.
    case gemini

    public var id: String {
        rawValue
    }
    public var title: String {
        switch self {
        case .onDevice: "On-device"
        case .realtime: "OpenAI Realtime"
        case .gemini: "Gemini Live"
        }
    }
    /// One line for pickers.
    public var tagline: String {
        switch self {
        case .onDevice: "Free · private · works offline"
        case .realtime: "Fastest · best quality · ~$2/hour"
        case .gemini: "Free to try · ~$2.20/hour after"
        }
    }
    /// Runs in the cloud: needs an API key and streams audio to the provider.
    public var isCloud: Bool {
        self != .onDevice
    }
    /// The cloud models detect the spoken language; the on-device engine needs it chosen.
    public var detectsSpokenLanguage: Bool {
        isCloud
    }
    /// Where this engine's API key is kept; nil for on-device.
    public var keyAccount: String? {
        switch self {
        case .onDevice: nil
        case .realtime: "openai-api-key"
        case .gemini: "gemini-api-key"
        }
    }
}
