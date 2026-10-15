import HearviaSession
import HearviaUI
import SwiftUI

/// Explains what iOS will show (screen-sharing sheet, red indicator, floating window) before the user meets it.
struct OnboardingView: View {
    let translator: LiveTranslator
    var done: () -> Void
    @State private var page = UserDefaults.standard.integer(forKey: "debugOnboardingPage") // launch arg: -debugOnboardingPage N
    private let lastPage = 5

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                permission.tag(1)
                floatingWindow.tag(2)
                tips.tag(3)
                languageChoice.tag(4)
                getReady.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    done()
                }
            } label: {
                Text(page < lastPage ? "Continue" : "Get Started")
            }
            .buttonStyle(HVButtonStyle(.primary, height: 54))
            .padding()
            .accessibilityIdentifier("onboardingNext")
        }
        .overlay(alignment: .topTrailing) {
            if page < lastPage {
                Button("Skip") { withAnimation { page = lastPage } }.foregroundStyle(Color.hvMuted).padding()
            }
        }
        .background(Color.hvGround.ignoresSafeArea())
        .foregroundStyle(Color.hvText)
    }

    private var welcome: some View {
        OnboardingPage(symbol: nil, title: "Live subtitles for anything you hear",
                       message: "Videos, podcasts, calls, or the person in front of you, translated as they speak.") {
            FeatureCard("apps.iphone", "Other apps", "Keep watching in Safari, YouTube or Podcasts. Hearvia never pauses them.")
            FeatureCard("mic", "Microphone", "Talks, lessons and conversations in the room.")
            FeatureCard("checkmark.shield", "Free and private on device", "Or switch to OpenAI Realtime for the fastest subtitles.")
        }
    }

    private var permission: some View {
        OnboardingPage(symbol: "rectangle.dashed.badge.record", title: "iOS will ask to share your screen",
                       message: "iOS only lets apps hear other apps' sound through screen sharing. When you tap the play button, choose **Share Entire Screen**.") {
            Bullet("waveform", "Hearvia uses only the sound. Screen images are thrown away immediately and never saved or uploaded.")
            Bullet("record.circle", "A red indicator stays in the status bar while Hearvia is listening. Tap it any time to stop.")
            Bullet("network", "OpenAI Realtime sends speech to OpenAI to translate. On-device mode keeps everything on your iPhone. Hearvia doesn't keep recordings.")
        }
    }

    private var floatingWindow: some View {
        OnboardingPage(symbol: "pip", title: "Subtitles float on top",
                       message: "When you switch to another app, subtitles appear in a slim floating window.") {
            Bullet("hand.draw", "Drag it anywhere — above or below the action.")
            Bullet("arrow.up.left.and.arrow.down.right", "Pinch to make it bigger or smaller.")
            Bullet("arrow.right.to.line", "Swipe it to the screen edge to hide it; swipe back to bring it out.")
        }
    }

    private var tips: some View {
        OnboardingPage(symbol: "lightbulb", title: "For the smoothest experience",
                       message: "A few things iOS decides for us:") {
            Bullet("1.circle", "Start Hearvia first, then open your video. Watch it full screen rather than in its own floating window — iOS shows only one floating window at a time.")
            Bullet("lock.shield", "Some streaming apps block screen sharing for protected movies. Those won't get subtitles.")
            Bullet("headphones", "Headphones and AirPods work fine — Hearvia hears the app, not the room.")
        }
    }

    private var languageChoice: some View {
        OnboardingPage(symbol: "globe", title: "Your languages",
                       message: "Pick the language you want to read. Change it any time from the home screen.") {
            LanguageCard(translator: translator)
        }
    }

    private var getReady: some View {
        OnboardingPage(symbol: "checkmark.seal", title: "Get ready",
                       message: "Both optional. Hearvia asks again when they're needed.") {
            MicrophonePermissionRow()
            FeatureCard("cpu", "On-device translator", "Downloads once, then works offline.", footer: {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                    .font(.footnote)
            })
        }
    }
}
