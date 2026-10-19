import HearviaSession
import HearviaUI
import SwiftUI

struct OnboardingView: View {
    let translator: LiveTranslator
    var done: () -> Void
    @State private var page = 0
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
            .frame(maxWidth: OnboardingLayout.readableWidth)
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
                       message: "Videos, podcasts, calls and people, translated as they speak.") {
            FeatureCard("apps.iphone", "Other apps", "What you're watching keeps playing.")
            FeatureCard("mic", "Microphone", "Talks, lessons and conversations.")
            FeatureCard("checkmark.shield", "Free and private on device", "Or OpenAI Realtime or Gemini Live for the fastest subtitles.")
        }
    }

    private var permission: some View {
        OnboardingPage(symbol: "rectangle.dashed.badge.record", title: "iOS will ask to share your screen",
                       message: "Choose **Share Entire Screen**. It's the only way iOS lets Hearvia hear other apps.") {
            Bullet("waveform", "Only the sound is used. The screen is never saved or uploaded.")
            Bullet("record.circle", "Tap the red indicator in the status bar to stop.")
            Bullet("network", "On-device keeps everything on your iPhone. OpenAI Realtime and Gemini Live send speech to OpenAI or Google.")
        }
    }

    private var floatingWindow: some View {
        OnboardingPage(symbol: "pip", title: "Subtitles float on top",
                       message: "Subtitles follow you to other apps in a floating window.") {
            Bullet("hand.draw", "Drag it anywhere.")
            Bullet("arrow.up.left.and.arrow.down.right", "Pinch to resize.")
            Bullet("arrow.right.to.line", "Swipe it to the edge to hide it.")
        }
    }

    private var tips: some View {
        OnboardingPage(symbol: "lightbulb", title: "Tips",
                       message: "iOS sets a few limits.") {
            Bullet("1.circle", "Start Hearvia first, then watch full screen. iOS shows one floating window at a time.")
            Bullet("lock.shield", "Protected movies in some streaming apps can't get subtitles.")
            Bullet("headphones", "Headphones and AirPods work fine.")
        }
    }

    private var languageChoice: some View {
        OnboardingPage(symbol: "globe", title: "Your languages",
                       message: "Pick the language to read. Change it any time.") {
            LanguageCard(translator: translator)
        }
    }

    private var getReady: some View {
        OnboardingPage(symbol: "checkmark.seal", title: "Get ready",
                       message: "Both optional. Hearvia asks again when needed.") {
            MicrophonePermissionRow()
            FeatureCard("cpu", "On-device translator", "Downloads once, then works offline.", footer: {
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                    .font(.footnote)
            })
        }
    }
}
