import AVFoundation
import HearviaAudio

enum CaptureSource: Hashable {
    case allApps
    case process(AudioProcess)
    case microphone
    case unavailable(String)

    var savedSelection: String? {
        switch self {
        case let .unavailable(bundleID): bundleID
        case .allApps: "all"
        case .microphone: "microphone"
        case let .process(process): process.bundleID.isEmpty ? nil : process.bundleID
        }
    }

    var symbol: String {
        switch self {
        case .allApps: "speaker.wave.2"
        case .process, .unavailable: "app.badge"
        case .microphone: "mic"
        }
    }

    /// `--source=microphone`, `--source=all`, or a process ID, bundle ID or name to tap; with `--autostart` this scripts a capture without the menus.
    init?(launchArguments: [String], processes: [AudioProcess]) {
        guard let value = launchArguments.first(where: { $0.hasPrefix("--source=") })?.dropFirst("--source=".count) else { return nil }
        let selection = String(value)
        switch CaptureSource(savedSelection: selection, processes: processes) {
        case .unavailable:
            guard let process = processes.first(where: { selection == "\($0.pid)" || $0.name == selection }) else { return nil }
            self = .process(process)
        case let source: self = source
        }
    }

    init(savedSelection value: String, processes: [AudioProcess]) {
        switch value {
        case "microphone": self = .microphone
        case "all": self = .allApps
        default: self = processes.first { $0.bundleID == value }.map(Self.process) ?? .unavailable(value)
        }
    }

    @MainActor func start(tap: ProcessTapCapture, microphone: MicrophoneCapture, sink: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async throws {
        switch self {
        case .unavailable: throw NSError(domain: "Hearvia.Capture", code: 1, userInfo: [NSLocalizedDescriptionKey: label])
        case .allApps: try tap.start(processes: nil, onBuffer: sink)
        case let .process(p): try tap.start(processes: [p.id], onBuffer: sink)
        case .microphone: try await microphone.start(onBuffer: sink)
        }
    }

    var label: String {
        switch self {
        case .allApps: String(localized: "All system audio")
        case let .process(p): p.name
        case let .unavailable(bundleID): String(localized: "\(bundleID) is unavailable")
        case .microphone: String(localized: "Microphone")
        }
    }
}
