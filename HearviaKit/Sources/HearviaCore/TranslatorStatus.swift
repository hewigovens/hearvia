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
        case .idle: String(localized: "Idle")
        case .needsAPIKey: String(localized: "No API key")
        case .loadingModels: String(localized: "Loading on-device models")
        case let .downloadingSpeech(percent): String(localized: "Downloading speech model \(percent)%")
        case .connecting(0): String(localized: "Connecting")
        case let .connecting(attempt): String(localized: "Reconnecting (\(attempt))")
        case let .reconnecting(seconds): String(localized: "Reconnecting in \(seconds) s")
        case .translating(onDevice: true): String(localized: "Translating on device")
        case .translating: String(localized: "Translating")
        case .paused: String(localized: "Paused — waiting for speech")
        case .stopped: String(localized: "Stopped")
        case .failed: String(localized: "Failed")
        }
    }
}
