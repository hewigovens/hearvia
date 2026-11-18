import Foundation
import HearviaAudio
import HearviaCore

extension AppModel {
    var standbyLanguage: String? {
        guard settings.warmMicrophone, settings.input == .microphone, settings.hasCompletedOnboarding,
              scene == "active", !session.systemInterrupted, !listening, !busy else { return nil }
        return translation.effectiveSourceLanguage
    }

    func stopStandby() {
        warmMicrophone?.stop()
        warmMicrophone = nil
        warmStatus = ""
    }

    func runStandby() async {
        guard !Task.isCancelled else { return }
        stopStandby()
        guard let request = standbyLanguage else { return }
        let microphone = MicrophoneCapture()
        let owner = "standby-\(UUID())"
        let standby = CaptionStandby(request: request) { [session] in
            microphone.stop()
            session.release(owner)
        }
        warmMicrophone = standby
        warmStatus = String(localized: "Preparing microphone captions…")
        func isCurrent() -> Bool {
            warmMicrophone === standby && standbyLanguage == request
        }
        await standby.run(language: request, isCurrent: isCurrent) { captions in
            try await session.acquire(owner, microphone: true)
            guard !Task.isCancelled, isCurrent() else { return }
            try await microphone.start(onBuffer: captions.receive)
        } readyStatus: { language in
            String(localized: "Microphone ready · \(LanguageName.localized(language))")
        } setStatus: { warmStatus = $0 }
        if warmMicrophone === standby {
            warmMicrophone = nil
            if Task.isCancelled {
                warmStatus = ""
            }
        }
    }
}
