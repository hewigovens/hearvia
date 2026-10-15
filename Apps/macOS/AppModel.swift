import AppKit
import AVFoundation
import HearviaKit
import Observation

enum CaptureSource: Hashable {
    case allApps
    case process(AudioProcess)
    case microphone

    var label: String {
        switch self {
        case .allApps: "All system audio"
        case .process(let p): p.name
        case .microphone: "Microphone"
        }
    }
}

@MainActor @Observable
final class AppModel {
    let translator = LiveTranslator(fallbackKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? DevSecrets.openAIKey)
    var source = CaptureSource.allApps
    var processes: [AudioProcess] = []
    private(set) var capturing = false
    private(set) var captureError = ""
    private(set) var levels = [Float](repeating: 0, count: 10)

    var overlayVisible = true { didSet { overlay?.setVisible(overlayVisible) } }
    var clickThrough = false { didSet { overlay?.ignoresMouseEvents = clickThrough } }
    var fontSize = 30.0
    var showSource = true
    var backgroundOpacity = 0.65

    @ObservationIgnored private var overlay: OverlayPanel?
    @ObservationIgnored private let tap = ProcessTapCapture()
    @ObservationIgnored private let microphone = MicrophoneCapture()
    @ObservationIgnored private let meter = LevelMeter()
    @ObservationIgnored private var meterTimer: Timer?
    let verbose = CommandLine.arguments.contains("--verbose")

    init() {
        refreshProcesses()
        translator.onLog = { [verbose] name, fields in if verbose { Self.emit(name, fields) } }
        if verbose {
            translator.onTextChange = { [weak self] in
                guard let self else { return }
                Self.emit("text", ["translation_tail": String(self.translator.translation.suffix(60))])
            }
        }
    }

    func showOverlay() {
        if overlay == nil { overlay = OverlayPanel(model: self) }
        overlay?.setVisible(overlayVisible)
    }

    func refreshProcesses() { processes = AudioProcesses.list() }

    func start() async {
        guard !capturing else { return }
        captureError = ""
        let feed = translator.feed
        let meter = meter
        let sink: @Sendable (AVAudioPCMBuffer) -> Void = { buffer in
            meter.measure(buffer)
            feed.push(buffer)
        }
        do {
            switch source {
            case .allApps: try tap.start(processes: nil, onBuffer: sink)
            case .process(let p): try tap.start(processes: [p.id], onBuffer: sink)
            case .microphone: try await microphone.start(onBuffer: sink)
            }
        } catch {
            captureError = error.localizedDescription
            Self.emit("capture_error", ["error": captureError])
            return
        }
        capturing = true
        Self.emit("capture_started", ["source": source.label, "format": tap.format.map { "\($0)" } ?? "mic"])
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; self.levels = Array(self.levels.dropFirst()) + [self.meter.take()] }
        }
        await translator.start()
    }

    func stop() async {
        guard capturing else { return }
        tap.stop(); microphone.stop()
        meterTimer?.invalidate(); meterTimer = nil; levels = levels.map { _ in 0 }
        capturing = false
        await translator.stop()
        Self.emit("capture_stopped", ["translation": translator.translation])
    }

    nonisolated static func emit(_ name: String, _ fields: [String: String]) {
        var record = fields; record["event"] = name
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .withoutEscapingSlashes]) {
            print(String(decoding: data, as: UTF8.self)); fflush(stdout)
        }
    }
}
