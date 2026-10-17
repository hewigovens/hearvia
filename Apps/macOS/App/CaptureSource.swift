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

    /// `--source=microphone`, `--source=all`, or a process ID, bundle ID or name to tap; with `--autostart` this scripts a capture without the menus.
    init?(launchArguments: [String], processes: [AudioProcess]) {
        guard let value = launchArguments.first(where: { $0.hasPrefix("--source=") })?.dropFirst("--source=".count) else { return nil }
        switch value {
        case "microphone": self = .microphone
        case "all": self = .allApps
        default:
            guard let process = processes.first(where: { value == "\($0.pid)" || $0.bundleID == value || $0.name == value }) else { return nil }
            self = .process(process)
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
