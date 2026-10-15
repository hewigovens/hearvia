import Foundation

/// Which pipeline turns captured audio into subtitles.
public enum TranslationEngine: String, CaseIterable, Identifiable, Sendable {
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
    public var summary: String {
        self == .realtime ? "Fastest, best quality. Uses OpenAI credit (~$2/hour)."
            : "Free and private. Runs on this device; a little behind the speaker."
    }
}
