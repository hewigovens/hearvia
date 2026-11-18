import Foundation
import HearviaAudio
import HearviaCore

extension AppModel {
    struct WarmRequest: Equatable {
        let source: CaptureSource
        let language: String
    }

    var warmRequest: WarmRequest? {
        guard settings.warmCaptions, !capturing, !starting else { return nil }
        if case .unavailable = source {
            return nil
        }
        return WarmRequest(source: source, language: translator.effectiveSourceLanguage)
    }

    func stopWarmCaptions() {
        warmSession?.stop()
        warmSession = nil
        warmStatus = ""
    }

    func warmIfNeeded() async {
        guard !Task.isCancelled else { return }
        stopWarmCaptions()
        guard let request = warmRequest else { return }
        let tap = ProcessTapCapture()
        let microphone = MicrophoneCapture()
        let session = CaptionStandby(request: request) {
            tap.stop()
            microphone.stop()
        }
        warmSession = session
        warmStatus = String(localized: "Warming on this Mac…")
        await session.run(language: request.language, isCurrent: { warmRequest == request && warmSession === session }) { captions in
            try await request.source.start(tap: tap, microphone: microphone, sink: captions.receive)
        } readyStatus: { language in
            String(localized: "Ready · \(LanguageName.localized(language)) on this Mac")
        } setStatus: { warmStatus = $0 }
        if warmSession === session {
            warmSession = nil
            if Task.isCancelled {
                warmStatus = ""
            }
        }
    }
}
