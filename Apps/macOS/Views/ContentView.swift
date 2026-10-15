import HearviaKit
import SwiftUI

/// Compact control window from the design canvas: source, languages and translator, overlay, Start/Stop.
struct ContentView: View {
    @Bindable var model: AppModel
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark
    @Environment(\.openWindow) private var openWindow
    @State private var lastApp = CaptureSource.allApps

    private var translator: LiveTranslator { model.translator }

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
        .preferredColorScheme(appearance.colorScheme)
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
                    Picker("App", selection: Binding(get: { model.source }, set: { model.source = $0; lastApp = $0 })) {
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
                                                    set: { l in if l != "auto" { Task { await translator.setSourceLanguage(l) } } })) {
                    if translator.engine == .realtime { Text("Auto-detect").tag("auto") }
                    ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageLabel.of($0)).tag($0) }
                }
                .labelsHidden()
                .disabled(translator.engine == .realtime)
                Image(systemName: "arrow.right").foregroundStyle(Color.hvMuted)
                Picker("Subtitles", selection: Binding(get: { translator.targetLanguage },
                                                       set: { l in Task { await translator.setTargetLanguage(l) } })) {
                    ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageLabel.of($0)).tag($0) }
                }
                .labelsHidden()
            }
            SegmentedChoice(selection: Binding(get: { translator.engine }, set: { e in Task { await translator.setEngine(e) } }),
                            options: TranslationEngine.allCases, title: \.shortTitle, height: 28) { $0 == .onDevice ? "cpu" : "cloud" }
            EngineStatusLine(translator: translator)
        }
    }

    private var overlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Overlay")
            Toggle("Show subtitle overlay", isOn: $model.overlayVisible)
            Toggle("Show original speech", isOn: $model.showSource)
            Toggle("Click-through (can't drag while on)", isOn: $model.clickThrough)
            HStack(spacing: 10) {
                Text("Size")
                Slider(value: $model.fontSize, in: 16...64)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Task { model.capturing ? await model.stop() : await model.start() }
                } label: {
                    Label(model.capturing ? "Stop" : "Start Listening", systemImage: model.capturing ? "stop.fill" : "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(HVButtonStyle(model.capturing ? .stop : .primary, height: 36))
                LevelBars(levels: model.levels).frame(width: 80)
            }
            if !model.captureError.isEmpty { Text(model.captureError).font(.caption).foregroundStyle(.red) }
            if !translator.error.isEmpty { Text(translator.error).font(.caption).foregroundStyle(.red) }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
    }
}

private extension Int {
    var inputTitle: String { self == 1 ? "Microphone" : "Apps" }
}

private extension TranslationEngine {
    var shortTitle: String { self == .onDevice ? "On-device · free" : "OpenAI Realtime" }
}

/// One line when the translator is ready; otherwise the missing model or key, with the fix inline.
struct EngineStatusLine: View {
    let translator: LiveTranslator
    @State private var ready: Bool?

    var body: some View {
        Group {
            if translator.engine == .realtime {
                if translator.apiKey.isEmpty {
                    SettingsLink { Label("Add an OpenAI API key in Settings", systemImage: "key") }
                        .buttonStyle(.link).font(.caption)
                } else {
                    line("Using your OpenAI API key", ok: true)
                }
            } else if ready == nil {
                line("Checking on-device models…", ok: false)
            } else if ready == true {
                line("Models ready", ok: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                }
                .font(.caption)
                .padding(10)
                .background(Color.hvSurface, in: .rect(cornerRadius: 8))
            }
        }
        .task(id: "\(translator.engine.rawValue)\(translator.sourceLanguage)\(translator.targetLanguage)") {
            ready = nil
            guard translator.engine == .onDevice else { return }
            let s = await OnDeviceModels.speech(translator.sourceLanguage)
            let t = await OnDeviceModels.translation(from: translator.sourceLanguage, to: translator.targetLanguage)
            ready = s == .installed && t == .installed
        }
    }

    private func line(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.hvReady : Color.hvMuted).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(Color.hvMuted)
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark

    var body: some View {
        Form {
            Section("OpenAI Realtime") {
                SecureField("API key", text: Bindable(model.translator).apiKey)
                Text("Only used by the OpenAI Realtime translator. Kept in your Keychain.").font(.caption).foregroundStyle(Color.hvMuted)
            }
            Section("On-device models") {
                OnDeviceModelsView(source: model.translator.sourceLanguage, target: model.translator.targetLanguage)
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Slider(value: $model.backgroundOpacity, in: 0...1) { Text("Overlay background") }
            }
            Section("Diagnostics") {
                Text("\(model.translator.state) · sent \(model.translator.chunksSent) × 200 ms · \(model.translator.deltas) deltas · \(model.translator.reconnects) reconnects")
                    .font(.caption).monospacedDigit().textSelection(.enabled)
                Text("Launch with --verbose to log JSON events to stdout.").font(.caption).foregroundStyle(Color.hvMuted)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.hvGround)
        .tint(.hvAccent)
        .preferredColorScheme(appearance.colorScheme)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct TranscriptView: View {
    let translator: LiveTranslator
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if translator.transcript.isEmpty {
                        Text("Finished sentences collect here, with the original above each translation.")
                            .foregroundStyle(Color.hvMuted)
                    }
                    ForEach(translator.transcript) { line in
                        VStack(alignment: .leading, spacing: 3) {
                            if !line.source.isEmpty { Text(line.source).font(.callout).foregroundStyle(Color.hvMuted) }
                            Text(line.translation).font(.title3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(line.id)
                    }
                }
                .textSelection(.enabled)
                .padding(20)
            }
            .onChange(of: translator.transcript.last?.id) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .preferredColorScheme(appearance.colorScheme)
        .toolbar {
            if !translator.transcript.isEmpty {
                ShareLink(item: translator.transcriptText)
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translator.transcriptText, forType: .string)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }
}
