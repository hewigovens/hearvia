import HearviaUI
import SwiftUI

/// Ready: subtitle preview, a centred listen button and the setup tiles. Listening: the button shrinks to the
/// bottom, the preview grows and the transcript takes the tiles' place.
struct HomeView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var phase
    @State private var presentation: HomePresentation?

    var body: some View {
        let listening = model.listening
        VStack(spacing: 16) {
            HomeHeader(model: model) { presentation = $0 }
            // The inline layer must stay on screen: PiP starts from it when the user leaves the app.
            SubtitlePreview(pip: model.pip)
                .aspectRatio(listening ? 1.5 : SubtitleRenderer.aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .accessibilityLabel(listening ? "Live subtitles" : "Subtitle preview")
            if listening {
                ListeningSummary(model: model)
                    .transition(.opacity)
            }
            // One slot either way, so the button keeps its identity and animates to the bottom.
            if listening {
                TranscriptCard(model: model)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)
            }
            ListenButton(listening: listening, busy: model.busy, size: listening ? 56 : 96) {
                Task { await model.toggleListening() }
            }
            .accessibilityIdentifier("listenToggle")
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
        .animation(.spring(duration: 0.55, bounce: 0.15), value: listening)
        .background(Color.hvGround.ignoresSafeArea())
        .foregroundStyle(Color.hvText)
        .onAppear {
            if !settings.hasCompletedOnboarding {
                presentation = .onboarding
            }
        }
        .onChange(of: phase) { _, value in model.sceneChanged(value) }
        .onChange(of: settings.floatsWhenLeaving) { Task { await model.updateFloating() } }
        .onChange(of: settings.subtitleScale) { model.scheduleRender() }
        .onChange(of: settings.showsOriginal) { model.scheduleRender() }
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
            case .languages: LanguagesSheet(translator: model.translation)
            case .translator: TranslatorSheet(translator: model.translation) { presentation = .settings }
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
