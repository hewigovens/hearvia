import Foundation
import HearviaAudio
import HearviaCore
import HearviaEngines

extension AppModel {
    var standbyLanguage: String? {
        guard settings.warmMicrophone, settings.input == .microphone, settings.hasCompletedOnboarding,
              scene == "active", !session.systemInterrupted, !listening, !busy else { return nil }
        return translation.engine.detectsSpokenLanguage ? "" : translation.sourceLanguage
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
        let standby = StandbyMicrophone(languageRequest: request, session: session)
        warmMicrophone = standby
        warmStatus = String(localized: "Preparing microphone captions…")
        defer {
            standby.stop()
            if warmMicrophone === standby {
                warmMicrophone = nil
            }
        }
        await withTaskCancellationHandler {
            do {
                let language = request.isEmpty ? await OnDeviceModels.autoCandidates().first : request
                guard let language else { throw OnDeviceError.noSpeechModels }
                let captions = try await WarmCaptions(language: language)
                standby.captions = captions
                try Task.checkCancellation()
                guard warmMicrophone === standby, standbyLanguage == request else { return }
                try await session.acquire(standby.owner, microphone: true)
                try Task.checkCancellation()
                guard warmMicrophone === standby, standbyLanguage == request else { return }
                try await standby.microphone.start(onBuffer: captions.receive)
                try Task.checkCancellation()
                guard warmMicrophone === standby, standbyLanguage == request else { return }
                warmStatus = String(localized: "Microphone ready · \(LanguageName.localized(language))")
                try await captions.run()
                if warmMicrophone === standby {
                    warmStatus = String(localized: "Warm captions stopped")
                }
            } catch {
                if !Task.isCancelled, warmMicrophone === standby {
                    warmStatus = String(localized: "Warm captions unavailable: \(error.localizedDescription)")
                }
            }
        } onCancel: {
            Task { @MainActor in standby.stop() }
        }
    }
}

@MainActor
final class StandbyMicrophone {
    let languageRequest: String
    let microphone = MicrophoneCapture()
    let owner = "standby-\(UUID())"
    let session: AudioSessionController
    var captions: WarmCaptions?

    init(languageRequest: String, session: AudioSessionController) {
        self.languageRequest = languageRequest
        self.session = session
    }

    func stop() {
        microphone.stop()
        session.release(owner)
        if let captions {
            self.captions = nil
            Task { await captions.close() }
        }
    }
}
