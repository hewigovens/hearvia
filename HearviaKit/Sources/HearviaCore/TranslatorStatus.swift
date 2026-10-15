/// Where a live translation run is, for status lines and diagnostics.
public enum TranslatorStatus: Equatable, Sendable {
    case idle
    case needsAPIKey
    case loadingModels
    case downloadingSpeech(percent: Int)
    /// `attempt` is 0 for the first connection, then counts reconnects.
    case connecting(attempt: Int)
    case reconnecting(inSeconds: Int)
    case translating(onDevice: Bool)
    /// The Realtime socket is closed during a long silence (it bills per connected minute) and reopens on sound.
    case paused
    case stopped
    case failed

    public var label: String {
        switch self {
        case .idle: "Idle"
        case .needsAPIKey: "No API key"
        case .loadingModels: "Loading on-device models"
        case let .downloadingSpeech(percent): "Downloading speech model \(percent)%"
        case let .connecting(attempt): attempt == 0 ? "Connecting" : "Reconnecting (\(attempt))"
        case let .reconnecting(seconds): "Reconnecting in \(seconds) s"
        case let .translating(onDevice): onDevice ? "Translating on device" : "Translating"
        case .paused: "Paused — waiting for speech"
        case .stopped: "Stopped"
        case .failed: "Failed"
        }
    }
}
