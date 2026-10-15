import HearviaCore
import HearviaSession
import HearviaUI
import SwiftUI

/// Compact control window from the design canvas: source, languages and translator, overlay, Start/Stop.
struct ControlView: View {
    @Bindable var model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @State private var lastApp = CaptureSource.allApps

    private var translator: LiveTranslator {
        model.translator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            listenSection
            translateSection
            overlaySection
            controls
        }
        .padding(20)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .tint(.hvAccent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .toolbar {
            ToolbarItemGroup {
                Button("Transcript", systemImage: "text.bubble") { openWindow(id: "transcript") }
                SettingsLink { Label("Settings", systemImage: "gearshape") }
            }
        }
    }

    // MARK: Sections

    private var listenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Listen to")
            SegmentedChoice(selection: Binding(get: { model.source == .microphone ? 1 : 0 },
                                               set: { model.source = $0 == 1 ? .microphone : lastApp }),
                            options: [0, 1], title: \.inputTitle, height: 28) { $0 == 1 ? "mic" : "macwindow" }
                .disabled(model.capturing)
            if model.source != .microphone {
                HStack(spacing: 6) {
                    Picker("App", selection: Binding(get: { model.source }, set: { model.source = $0
                        lastApp = $0
                    })) {
                        Label("All system audio", systemImage: "speaker.wave.2").tag(CaptureSource.allApps)
                        Divider()
                        ForEach(model.processes.sorted { $0.isOutputting && !$1.isOutputting }) { p in
                            Text(p.isOutputting ? "\(p.name) — playing audio" : p.name).tag(CaptureSource.process(p))
                        }
                    }
                    .labelsHidden()
                    Button { model.refreshProcesses() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                        .help("Refresh the app list")
                }
                .disabled(model.capturing)
                Text("Browsers often play through a helper process. Choose All system audio if unsure.")
                    .font(.caption).foregroundStyle(Color.hvMuted)
            }
        }
    }

    private var translateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("Translate")
            HStack(spacing: 8) {
                Picker("Spoken", selection: Binding(get: { translator.engine == .realtime ? "auto" : translator.sourceLanguage },
                                                    set: { language in
                                                        guard language != "auto" else { return }
                                                        Task { await translator.setSourceLanguage(language) }
                                                    })) {
                    if translator.engine == .realtime {
                        Text("Auto-detect").tag("auto")
                    }
                    ForEach(OnDeviceLanguages.shared.spokenChoices(for: translator.engine, including: translator.sourceLanguage), id: \.self) { Text(LanguageName.localized($0)).tag($0) }
                }
                .labelsHidden()
                .disabled(translator.engine == .realtime)
                Image(systemName: "arrow.right").foregroundStyle(Color.hvMuted)
                Picker("Subtitles", selection: Binding(get: { translator.targetLanguage },
                                                       set: { l in Task { await translator.setTargetLanguage(l) } })) {
                    ForEach(OnDeviceLanguages.shared.subtitleChoices(for: translator.engine, including: translator.targetLanguage), id: \.self) { Text(LanguageName.localized($0)).tag($0) }
                }
                .labelsHidden()
            }
            SegmentedChoice(selection: Binding(get: { translator.engine }, set: { e in Task { await translator.setEngine(e) } }),
                            options: EngineKind.allCases, title: \.shortTitle, height: 28) { $0 == .onDevice ? "cpu" : "cloud" }
            EngineStatusLine(translator: translator)
        }
    }

    private var overlaySection: some View {
        @Bindable var settings = settings
        return VStack(alignment: .leading, spacing: 10) {
            caption("Overlay")
            Toggle("Show subtitle overlay", isOn: $settings.overlayVisible)
            Toggle("Show original speech", isOn: $settings.showsOriginal)
            Toggle("Click-through (can't drag while on)", isOn: $settings.clickThrough)
            HStack(spacing: 10) {
                Text("Size")
                Slider(value: $settings.overlayFontSize, in: AppSettings.overlayFontSizeRange)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Task { await model.toggleListening { openWindow(id: "permissions") } }
                } label: {
                    Label(model.capturing ? "Stop" : "Start Listening", systemImage: model.capturing ? "stop.fill" : "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(HVButtonStyle(model.capturing ? .stop : .primary, height: 36))
                LevelBars(levels: model.levels).frame(width: 80)
            }
            if !model.captureError.isEmpty {
                Text(model.captureError).font(.caption).foregroundStyle(.red)
            }
            if !translator.error.isEmpty {
                Text(translator.error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
    }
}

private extension Int {
    var inputTitle: String {
        self == 1 ? "Microphone" : "Apps"
    }
}

private extension EngineKind {
    var shortTitle: String {
        self == .onDevice ? "On-device · free" : "OpenAI Realtime"
    }
}
