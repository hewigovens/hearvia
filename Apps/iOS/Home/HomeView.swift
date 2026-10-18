import HearviaUI
import SwiftUI

struct HomeView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @State private var presentation: HomePresentation?

    var body: some View {
        GeometryReader { proxy in
            if model.listening, proxy.size.width > proxy.size.height {
                CaptionMode(model: model)
            } else if widthClass == .regular, heightClass == .regular, !model.listening {
                wide
            } else {
                narrow
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.15), value: model.listening)
        .background(Color.hvGround.ignoresSafeArea())
        .foregroundStyle(Color.hvText)
        .onAppear {
            if !settings.hasCompletedOnboarding {
                presentation = .onboarding
            }
            #if DEBUG
                // Caption-mode screenshots: the Simulator can't be rotated from the command line.
                if UserDefaults.standard.bool(forKey: "hearvia.demoLandscape"),
                   let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                }
                // Starts a session at launch for on-device debugging (-hearvia.autostart microphone).
                if let source = UserDefaults.standard.string(forKey: "hearvia.autostart").flatMap(InputSource.init) {
                    model.quickStart(source)
                }
            #endif
        }
        .onChange(of: phase) { _, value in
            model.sceneChanged(value)
            startIfRequested()
        }
        .onChange(of: QuickStart.shared.request, initial: true) { startIfRequested() }
        .onChange(of: settings.floatsWhenLeaving) { Task { await model.updateFloating() } }
        .onChange(of: settings.subtitleScale) { model.scheduleRender() }
        .onChange(of: settings.showsOriginal) { model.scheduleRender() }
        .onChange(of: settings.originalLarge) { model.scheduleRender() }
        .onChange(of: model.pip.restoreRequested) { _, requested in
            if requested {
                Task { await Task.yield()
                    model.pip.finishRestore()
                }
            }
        }
        .sheet(item: sheet) { kind in
            switch kind {
            case .settings: SettingsView(model: model) { presentation = .onboarding }
            case .source: SourceSheet()
            case .languages: LanguagesSheet(translator: model.translation)
            case .translator: TranslatorSheet(translator: model.translation) { presentation = .settings }
            case .transcripts: TranscriptsSheet(translator: model.translation)
            case .onboarding: EmptyView()
            }
        }
        .fullScreenCover(item: onboarding) { _ in
            OnboardingView(translator: model.translation) {
                settings.hasCompletedOnboarding = true
                presentation = nil
            }
        }
    }

    private var narrow: some View {
        let listening = model.listening
        return VStack(spacing: 16) {
            HomeHeader(model: model) { presentation = $0 }
            preview
            if listening {
                ListeningSummary(model: model)
                    .transition(.offset(y: 12).combined(with: .opacity))
                LiveTranscriptCard(translator: model.translation)
                    .transition(.opacity)
            } else {
                Spacer(minLength: 0)
            }
            listenButton(size: listening ? 56 : 96)
            if !listening {
                StartPrompt(model: model)
                    .transition(.opacity)
                Spacer(minLength: 0)
                HomeTiles(model: model) { presentation = $0 }
                    .transition(.offset(y: 40).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    /// The open iPhone Duo, or an iPad, while idle: a wide preview over the button and the tiles side by side. Listening uses the single column (wide and landscape means caption mode).
    private var wide: some View {
        VStack(spacing: 20) {
            HomeHeader(model: model) { presentation = $0 }
            preview
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 32) {
                VStack(spacing: 12) {
                    listenButton(size: 112)
                    StartPrompt(model: model)
                }
                .frame(maxWidth: .infinity)
                HomeTiles(model: model) { presentation = $0 }
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    /// The inline layer must stay on screen: PiP starts from it when the user leaves the app.
    private var preview: some View {
        SubtitlePreview(pip: model.pip)
            .aspectRatio(SubtitleRenderer.aspectRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .accessibilityLabel(model.listening ? "Live subtitles" : "Subtitle preview")
    }

    private func listenButton(size: CGFloat) -> some View {
        ListenButton(listening: model.listening, busy: model.busy, size: size) {
            Task { await model.toggleListening() }
        }
        .accessibilityIdentifier("listenToggle")
    }

    /// Before onboarding is done the request is dropped rather than kept, so it can't start listening at some later, unexpected moment.
    private func startIfRequested() {
        guard phase == .active, let request = QuickStart.shared.take(), settings.hasCompletedOnboarding else { return }
        presentation = nil
        model.quickStart(request.source)
    }

    private var sheet: Binding<HomePresentation?> {
        Binding(get: { presentation == .onboarding ? nil : presentation }, set: {
            if $0 == nil, presentation != .onboarding {
                presentation = nil
            }
        })
    }

    private var onboarding: Binding<HomePresentation?> {
        Binding(get: { presentation == .onboarding ? .onboarding : nil }, set: {
            if $0 == nil, presentation == .onboarding {
                presentation = nil
            }
        })
    }
}
