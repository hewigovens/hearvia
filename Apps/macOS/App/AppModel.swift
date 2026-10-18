import AppKit
import HearviaAudio
import HearviaCore
import HearviaSession
import Observation

@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let translator = LiveTranslator(fallbackKeys: AppModel.developmentKeys)
    var source = CaptureSource.allApps
    var processes: [AudioProcess] = []
    var capturing = false
    var capturingSince: Date?
    var captureError = ""
    var levels = [Float](repeating: 0, count: 10)

    @ObservationIgnored private var overlay: OverlayPanel?
    @ObservationIgnored let tap = ProcessTapCapture()
    @ObservationIgnored let microphone = MicrophoneCapture()
    @ObservationIgnored let meter = LevelMeter()
    @ObservationIgnored var meterTimer: Timer?
    /// Set once the menu bar label appears; opening windows needs SwiftUI's `openWindow`.
    @ObservationIgnored var openWindow: ((String) -> Void)?
    let verbose = CommandLine.arguments.contains("--verbose")

    init(settings: AppSettings) {
        self.settings = settings
        RetiredFiles.remove()
        refreshProcesses()
        source = CaptureSource(launchArguments: CommandLine.arguments, processes: processes) ?? source
        followShowsOriginal()
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
        #if DEBUG
            if LiveTranslator.demoRequested { // App Store screenshots (see LiveTranslator+Demo).
                capturing = true
                capturingSince = .now.addingTimeInterval(-754)
                levels = [0.2, 0.5, 0.35, 0.7, 0.45, 0.6, 0.3, 0.55, 0.4, 0.65]
                translator.loadDemo()
            }
        #endif
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

    private func followShowsOriginal() {
        let shows = withObservationTracking {
            settings.needsOriginal
        } onChange: { [weak self] in
            Task { @MainActor in self?.followShowsOriginal() }
        }
        Task { await translator.setTranscribesSource(shows) }
    }

    /// Debug builds may take keys from the environment or `.env`; Release users paste their own.
    private static var developmentKeys: [EngineKind: String] {
        #if DEBUG
            let environment = ProcessInfo.processInfo.environment
            return [.realtime: environment["OPENAI_API_KEY"] ?? DevSecrets.openAIKey,
                    .gemini: environment["GEMINI_API_KEY"] ?? DevSecrets.geminiKey]
        #else
            [:]
        #endif
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
