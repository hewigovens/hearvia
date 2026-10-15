import AppKit
import HearviaKit
import Observation

/// Owns capture and the translator; drives the overlay panel from `AppSettings`.
@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let translator = LiveTranslator(fallbackKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? DevSecrets.openAIKey)
    var source = CaptureSource.allApps
    var processes: [AudioProcess] = []
    var capturing = false
    var captureError = ""
    var levels = [Float](repeating: 0, count: 10)

    @ObservationIgnored private var overlay: OverlayPanel?
    @ObservationIgnored let tap = ProcessTapCapture()
    @ObservationIgnored let microphone = MicrophoneCapture()
    @ObservationIgnored let meter = LevelMeter()
    @ObservationIgnored var meterTimer: Timer?
    let verbose = CommandLine.arguments.contains("--verbose")

    init(settings: AppSettings) {
        self.settings = settings
        refreshProcesses()
        translator.onLog = { [verbose] name, fields in
            guard verbose else { return }
            Self.emit(name, fields)
        }
        if verbose {
            translator.onTextChange = { [weak self] in
                guard let self else { return }
                Self.emit("text", ["translation_tail": String(self.translator.translation.suffix(60))])
            }
        }
    }

    func showOverlay() {
        if overlay == nil {
            overlay = OverlayPanel(model: self)
        }
        applyOverlaySettings()
    }

    /// The panel is AppKit, so settings changes reach it by re-registering an observation after each change.
    private func applyOverlaySettings() {
        withObservationTracking {
            overlay?.setVisible(settings.overlayVisible)
            overlay?.ignoresMouseEvents = settings.clickThrough
        } onChange: { [weak self] in
            Task { @MainActor in self?.applyOverlaySettings() }
        }
    }

    func refreshProcesses() {
        processes = AudioProcesses.list()
    }

    nonisolated static func emit(_ name: String, _ fields: [String: String]) {
        var record = fields
        record["event"] = name
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .withoutEscapingSlashes]) {
            print(String(decoding: data, as: UTF8.self))
            fflush(stdout)
        }
    }
}
