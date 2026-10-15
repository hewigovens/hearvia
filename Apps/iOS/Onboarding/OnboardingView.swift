import HearviaKit
import SwiftUI

/// Explains what iOS will show (screen-sharing sheet, red indicator, floating window)
/// before the user meets it, and promises the one thing that matters: Hearvia never
/// interrupts what they are watching or listening to.
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
                       message: "iOS only lets apps hear other apps' sound through screen sharing. When you tap Start Listening, choose **Share Entire Screen**.") {
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
                       message: "Pick the language you want to read. OpenAI Realtime detects the spoken language by itself; the on-device translator needs to know it. Change either any time.") {
            HStack {
                Text("Spoken language")
                Spacer()
                Picker("Spoken language", selection: Binding(get: { translator.sourceLanguage },
                                                             set: { l in Task { await translator.setSourceLanguage(l) } })) {
                    ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageName.of($0)).tag($0) }
                }
                .labelsHidden()
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(Color.hvSurface, in: .rect(cornerRadius: 14, style: .continuous))
            Text("Subtitles in").font(.subheadline.weight(.semibold)).padding(.top, 4)
            Picker("Subtitle language", selection: Binding(get: { translator.targetLanguage },
                                                           set: { l in Task { await translator.setTargetLanguage(l) } })) {
                ForEach(LiveTranslator.languages, id: \.self) { Text(LanguageName.of($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
    }

    private var getReady: some View {
        OnboardingPage(symbol: "checkmark.seal", title: "Get ready",
                       message: "Two optional steps that save waiting later. If you skip them, Hearvia asks when they are first needed.") {
            MicrophonePermissionRow()
            VStack(alignment: .leading, spacing: 10) {
                Text("Free on-device translator").font(.subheadline.weight(.semibold))
                OnDeviceModelsView(source: translator.sourceLanguage, target: translator.targetLanguage)
                    .font(.subheadline)
                Text("Downloads once over Wi-Fi, then works offline.").font(.footnote).foregroundStyle(Color.hvMuted)
            }
            .padding(16)
            .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
            Bullet("rectangle.dashed.badge.record", "Listening to other apps asks to share your screen each time you start. iOS doesn't allow asking ahead.")
        }
    }
}
