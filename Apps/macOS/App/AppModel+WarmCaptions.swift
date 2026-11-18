import Foundation
import HearviaAudio
import HearviaCore
import HearviaEngines

extension AppModel {
    struct WarmRequest: Equatable {
        let source: CaptureSource
        let language: String
    }

    var warmRequest: WarmRequest? {
        guard settings.warmCaptions, !capturing, !starting else { return nil }
        return WarmRequest(source: source, language: translator.engine.detectsSpokenLanguage ? "" : translator.sourceLanguage)
    }

    func warmIfNeeded() async {
        guard let request = warmRequest else {
            warmSession?.stop()
            warmSession = nil
            warmStatus = ""
            return
        }
        let session = WarmSession(request: request)
        warmSession?.stop()
        warmSession = session
        warmStatus = String(localized: "Warming on this Mac…")
        defer {
            session.stop()
            if warmSession === session {
                warmSession = nil
            }
        }
        await withTaskCancellationHandler {
            do {
                let language = request.language.isEmpty ? await OnDeviceModels.autoCandidates().first : request.language
                guard let language else { throw OnDeviceError.noSpeechModels }
                let captions = try await WarmCaptions(language: language)
                session.captions = captions
                try Task.checkCancellation()
                guard warmRequest == request, warmSession === session else { return }
                try await request.source.start(tap: session.tap, microphone: session.microphone, sink: captions.receive)
                try Task.checkCancellation()
                guard warmRequest == request, warmSession === session else { return }
                warmStatus = String(localized: "Ready · \(LanguageName.localized(language)) on this Mac")
                try await captions.run()
                if !Task.isCancelled, warmSession === session {
                    warmStatus = String(localized: "Warm captions stopped")
                }
            } catch {
                if !Task.isCancelled, warmSession === session, warmRequest == request {
                    warmStatus = String(localized: "Warm captions unavailable: \(error.localizedDescription)")
                }
            }
        } onCancel: {
            Task { @MainActor in
                session.stop()
                if self.warmSession === session {
                    self.warmStatus = ""
                }
            }
        }
    }
}

@MainActor
final class WarmSession {
    let request: AppModel.WarmRequest
    let tap = ProcessTapCapture()
    let microphone = MicrophoneCapture()
    var captions: WarmCaptions?

    init(request: AppModel.WarmRequest) {
        self.request = request
    }

    func stop() {
        tap.stop()
        microphone.stop()
        if let captions {
            self.captions = nil
            Task { await captions.close() }
        }
    }
}
