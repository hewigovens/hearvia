import HearviaKit
import SwiftUI

struct HomeView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var phase
    @State private var presentation: HomePresentation?

    var body: some View {
        VStack(spacing: 14) {
            HomeHeader(model: model) { presentation = $0 }
            // The inline layer must stay on screen: PiP starts from it when the user leaves the app.
            SubtitlePreview(pip: model.pip)
                .aspectRatio(SubtitleRenderer.aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Subtitle preview")
            if model.listening {
                ListeningPanel(model: model)
            } else {
                ScrollView { ReadyPanel(model: model) { presentation = .settings }.padding(.bottom, 8) }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .safeAreaInset(edge: .bottom) { ListenControls(model: model) }
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
        .sheet(item: presented(.settings)) { _ in
            SettingsView(model: model) { presentation = .onboarding }
        }
        .fullScreenCover(item: presented(.onboarding)) { _ in
            OnboardingView(translator: model.translation) {
                settings.hasCompletedOnboarding = true
                presentation = nil
            }
        }
    }

    private func presented(_ kind: HomePresentation) -> Binding<HomePresentation?> {
        Binding(get: { presentation == kind ? kind : nil }, set: {
            if $0 == nil, presentation == kind {
                presentation = nil
            }
        })
    }
}
