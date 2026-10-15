import Foundation

/// Which pipeline turns captured audio into subtitles.
public enum EngineKind: String, CaseIterable, Identifiable, Sendable {
    /// SpeechTranscriber + Translation framework: free, offline, sentence-level lag.
    case onDevice
    /// gpt-realtime-translate over WebSocket: lowest lag, paid per minute.
    case realtime

    public var id: String {
        rawValue
    }
    public var title: String {
        self == .realtime ? "OpenAI Realtime" : "On-device"
    }
    /// The Realtime model detects the spoken language; the on-device engine needs it chosen.
    public var detectsSpokenLanguage: Bool {
        self == .realtime
    }
    public var summary: String {
        self == .realtime ? "Fastest, best quality. Uses OpenAI credit (~$2/hour)."
            : "Free and private. Runs on this device; a little behind the speaker."
    }
}
