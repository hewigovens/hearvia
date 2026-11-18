import AVFoundation
import HearviaAudio

enum CaptureSource: Hashable {
    case allApps
    case process(AudioProcess)
    case microphone

    var savedSelection: String? {
        switch self {
        case .allApps: "all"
        case .microphone: "microphone"
        case let .process(process): process.bundleID.isEmpty ? nil : process.bundleID
        }
    }

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
        self.init(selection: String(value), processes: processes)
    }

    init?(selection value: String, processes: [AudioProcess]) {
        switch value {
        case "microphone": self = .microphone
        case "all": self = .allApps
        default:
            guard let process = processes.first(where: { value == "\($0.pid)" || $0.bundleID == value || $0.name == value }) else { return nil }
            self = .process(process)
        }
    }

    @MainActor func start(tap: ProcessTapCapture, microphone: MicrophoneCapture, sink: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        switch self {
        case .allApps: try tap.start(processes: nil, onBuffer: sink)
        case let .process(p): try tap.start(processes: [p.id], onBuffer: sink)
        case .microphone: try await microphone.start(onBuffer: sink)
        }
    }

    var label: String {
        switch self {
        case .allApps: String(localized: "All system audio")
        case let .process(p): p.name
        case .microphone: String(localized: "Microphone")
        }
    }
}
