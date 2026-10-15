import HearviaKit
import SwiftUI

struct HomeView: View {
    @Bindable var model: AppModel
    @State var showOnboarding: Bool
    @State private var showSettings = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @Environment(\.scenePhase) private var phase

    private var translator: LiveTranslator { model.translation }
    private var busy: Bool { model.listening || model.capture.pending || model.micStarting }

    var body: some View {
        VStack(spacing: 14) {
            header
            // The inline layer must stay on screen: PiP starts from it when the user leaves the app.
            SubtitlePreview(pip: model.pip)
                .aspectRatio(SubtitleRenderer.aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Subtitle preview")
            if model.listening {
                listeningContent
            } else {
                ScrollView { readyContent.padding(.bottom, 8) }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background(Color.hvGround.ignoresSafeArea())
        .foregroundStyle(Color.hvText)
        .onChange(of: phase) { _, value in model.sceneChanged(value) }
        .onChange(of: model.pip.restoreRequested) { _, requested in
            if requested { Task { await Task.yield(); model.pip.finishRestore() } }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(model: model) { showSettings = false; showOnboarding = true }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(translator: translator) {
                onboardingCompleted = true
                showOnboarding = false
            }
        }
    }

    // MARK: Header

    @ViewBuilder private var header: some View {
        HStack {
            if model.listening {
                HStack(spacing: 10) {
                    Circle().fill(Color.hvAccent).frame(width: 10, height: 10)
                        .background(Circle().fill(Color.hvAccent.opacity(0.28)).frame(width: 18, height: 18))
                    Text("Listening · \(model.micRunning ? "Microphone" : "Other apps")").font(.subheadline.weight(.semibold))
                    if let since = model.listeningSince {
                        TimelineView(.periodic(from: since, by: 1)) { context in
                            Text(Duration.seconds(context.date.timeIntervalSince(since).rounded(.down)),
                                 format: .time(pattern: .minuteSecond))
                                .font(.subheadline).monospacedDigit().foregroundStyle(Color.hvMuted)
                        }
                    }
                }
                .padding(.vertical, 8).padding(.horizontal, 14)
                .background(Color.hvAccentSoft, in: .capsule)
            } else {
                Text("Hearvia").font(.system(size: 32, weight: .bold)).tracking(-0.5)
            }
            Spacer()
            if !model.listening {
                CircleButton(symbol: "questionmark", label: "How it works") { showOnboarding = true }
            }
            CircleButton(symbol: "gearshape", label: "Settings") { showSettings = true }
                .accessibilityIdentifier("settings")
        }
    }

    // MARK: Ready

    private var readyContent: some View {
        VStack(spacing: 14) {
            if model.capture.pending {
                Card {
                    Label("Waiting for permission", systemImage: "hand.tap").font(.headline)
                    Text("Tap **Share Entire Screen** on the iOS sheet. Hearvia only uses the sound.")
                        .font(.subheadline).foregroundStyle(Color.hvMuted)
                }
            }
            SegmentedChoice(selection: $model.input, options: InputSource.allCases, title: \.title,
                            symbol: { $0 == .microphone ? "mic" : "square.grid.2x2" })
                .disabled(busy)
            languageCard
            HStack(spacing: 10) {
                ForEach(TranslationEngine.allCases) { engine in
                    EngineCard(engine: engine, selected: translator.engine == engine) {
                        Task { await translator.setEngine(engine) }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            EngineStatus(translator: translator) { showSettings = true }
            Toggle("Also show original speech", isOn: $model.bilingual)
                .padding(.horizontal, 16).frame(minHeight: 52)
                .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private var languageCard: some View {
        HStack(spacing: 4) {
            Menu {
                Picker("Spoken language", selection: Binding(get: { translator.sourceLanguage },
                                                             set: { l in Task { await translator.setSourceLanguage(l) } })) {
                    ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
            } label: {
                LanguageLabel(caption: "Spoken", value: translator.engine == .realtime ? "Auto-detect" : LanguageName.short(translator.sourceLanguage),
                              alignment: .leading)
            }
            .disabled(translator.engine == .realtime)
            Button {
                let spoken = translator.sourceLanguage, target = translator.targetLanguage
                Task { await translator.setSourceLanguage(target); await translator.setTargetLanguage(spoken) }
            } label: {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.hvAccent)
                    .frame(width: 44, height: 44).background(Color.hvSurfaceRaised, in: .circle)
            }
            .disabled(translator.engine == .realtime)
            .opacity(translator.engine == .realtime ? 0.4 : 1)
            .accessibilityLabel("Swap languages")
            Menu {
                Picker("Subtitles in", selection: Binding(get: { translator.targetLanguage },
                                                          set: { l in Task { await translator.setTargetLanguage(l) } })) {
                    ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
            } label: {
                LanguageLabel(caption: "Subtitles", value: LanguageName.short(translator.targetLanguage), alignment: .trailing)
            }
        }
        .padding(6)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }

    // MARK: Listening

    private var listeningContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                LevelBars(levels: model.levels)
                Text("\(translator.engine == .realtime ? "Auto" : LanguageName.short(translator.sourceLanguage)) → \(LanguageName.short(translator.targetLanguage)) · \(translator.engine.title)")
                    .font(.footnote).foregroundStyle(Color.hvMuted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            if model.capture.running && !model.pip.active {
                Text("Now open the app you want to watch or listen to. Subtitles follow you in a floating window.")
                    .font(.footnote).foregroundStyle(Color.hvMuted).frame(maxWidth: .infinity, alignment: .leading)
            }
            TranscriptCard(translator: translator)
            if !model.pip.active {
                Button { model.pip.start() } label: { Label("Show floating subtitles", systemImage: "pip.enter") }
                    .buttonStyle(HVButtonStyle(.secondary, height: 48))
            }
        }
    }

    // MARK: Bottom

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !friendlyError.isEmpty {
                Text(friendlyError).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            if model.listening {
                Button { Task { await model.stopListening() } } label: { Label("Stop Listening", systemImage: "stop.fill") }
                    .buttonStyle(HVButtonStyle(.stop))
            } else if busy {
                Button { Task { await model.stopListening() } } label: { Text("Cancel") }
                    .buttonStyle(HVButtonStyle(.secondary))
            } else {
                Button { model.startListening() } label: { Label("Start Listening", systemImage: "play.fill") }
                    .buttonStyle(HVButtonStyle(.primary))
                Text("Other apps keep playing. Hearvia never plays sound.")
                    .font(.footnote).foregroundStyle(Color.hvMuted)
            }
        }
        .accessibilityIdentifier("listenToggle")
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
        .background(Color.hvGround)
    }

    private var friendlyError: String {
        let e = [translator.error, model.capture.error, model.micError].filter { !$0.isEmpty }.joined(separator: "\n")
        if e.contains("invalid_api_key") { return "The OpenAI key was rejected. Check it in Settings." }
        if e.contains("insufficient_quota") { return "The OpenAI account has no remaining credit. Try the on-device translator." }
        return e
    }
}

// MARK: - Pieces

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(Color.hvText)
                .frame(width: 44, height: 44).background(Color.hvSurface, in: .circle)
        }
        .accessibilityLabel(label)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

private struct LanguageLabel: View {
    let caption: String
    let value: String
    let alignment: HorizontalAlignment
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(caption).font(.caption).foregroundStyle(Color.hvMuted)
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.hvText).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: alignment == .leading ? .leading : .trailing)
        .padding(.horizontal, 12)
        .contentShape(.rect)
    }
}

private struct EngineCard: View {
    let engine: TranslationEngine
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(engine.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.hvText)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.hvAccent : Color.hvLine)
                }
                Text(engine == .onDevice ? "Free · private · works offline" : "Fastest · best quality · ~$2/hour")
                    .font(.footnote).foregroundStyle(Color.hvMuted).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(selected ? Color.hvAccentSoft : Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.hvAccent : Color.hvLine, lineWidth: 1.5))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One line when the chosen translator is ready; otherwise what's missing, with the fix inline.
private struct EngineStatus: View {
    let translator: LiveTranslator
    let openSettings: () -> Void
    @State private var ready: Bool?

    var body: some View {
        Group {
            if translator.engine == .realtime {
                if translator.apiKey.isEmpty {
                    Button(action: openSettings) {
                        Label("Add an OpenAI API key in Settings", systemImage: "key")
                    }
                    .font(.footnote)
                } else {
                    readyLine("Connected with your OpenAI API key")
                }
            } else if ready == true {
                readyLine("Speech and translation models ready")
            } else if ready == nil {
                Label("Checking on-device models…", systemImage: "hourglass").font(.footnote).foregroundStyle(Color.hvMuted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                        .font(.subheadline)
                }
                .padding(14)
                .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .task(id: "\(translator.engine.rawValue)\(translator.sourceLanguage)\(translator.targetLanguage)") {
            ready = nil
            guard translator.engine == .onDevice else { return }
            let s = await OnDeviceModels.speech(translator.sourceLanguage)
            let t = await OnDeviceModels.translation(from: translator.sourceLanguage, to: translator.targetLanguage)
            ready = s == .installed && t == .installed
        }
    }

    private func readyLine(_ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hvReady) }
            .font(.footnote).foregroundStyle(Color.hvMuted)
    }
}

private struct TranscriptCard: View {
    let translator: LiveTranslator
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRANSCRIPT").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
                Spacer()
                if !translator.transcript.isEmpty {
                    ShareLink(item: translator.transcriptText) { Text("Share").font(.subheadline) }
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if translator.transcript.isEmpty {
                            Text("Finished sentences collect here, with the original above each translation.")
                                .font(.subheadline).foregroundStyle(Color.hvMuted)
                        }
                        ForEach(translator.transcript) { line in
                            VStack(alignment: .leading, spacing: 4) {
                                if !line.source.isEmpty {
                                    Text(line.source).font(.footnote).foregroundStyle(Color.hvMuted)
                                }
                                Text(line.translation).font(.callout)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(line.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: translator.transcript.last?.id) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

enum LanguageName {
    static func of(_ code: String) -> String {
        let native = Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
        let local = Locale.current.localizedString(forLanguageCode: code) ?? code
        return native.localizedCaseInsensitiveCompare(local) == .orderedSame ? native.capitalized : "\(native.capitalized) · \(local)"
    }

    /// The language's own name, e.g. "English", "中文", "日本語".
    static func short(_ code: String) -> String {
        (Locale(identifier: code).localizedString(forLanguageCode: code) ?? code).capitalized
    }
}
