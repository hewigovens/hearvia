enum CaptureSource: Hashable {
    case allApps
    case process(AudioProcess)
    case microphone

    var label: String {
        switch self {
        case .allApps: "All system audio"
        case let .process(p): p.name
        case .microphone: "Microphone"
        }
    }
}
