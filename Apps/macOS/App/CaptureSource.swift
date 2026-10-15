enum CaptureSource: Hashable {
    case allApps
    case process(AudioProcess)
    case microphone

    var symbol: String {
        switch self {
        case .allApps: "speaker.wave.2"
        case .process: "app.badge"
        case .microphone: "mic"
        }
    }

    var label: String {
        switch self {
        case .allApps: "All system audio"
        case let .process(p): p.name
        case .microphone: "Microphone"
        }
    }
}
