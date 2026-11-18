import Foundation
import HearviaEngines

@MainActor
final class CaptionStandby<Request: Equatable> {
    private let request: Request
    private var captions: WarmCaptions?
    private let stopCapture: () -> Void

    init(request: Request, stopCapture: @escaping () -> Void) {
        self.request = request
        self.stopCapture = stopCapture
    }

    func snapshot(for currentRequest: Request?) -> String {
        currentRequest == request ? captions?.snapshot() ?? "" : ""
    }

    func stop() {
        stopCapture()
        if let captions {
            self.captions = nil
            Task { await captions.close() }
        }
    }

    func run(language: String, isCurrent: () -> Bool,
             startCapture: (WarmCaptions) async throws -> Void,
             readyStatus: (String) -> String, setStatus: (String) -> Void) async {
        defer { stop() }
        await withTaskCancellationHandler {
            do {
                let captions = try await WarmCaptions(language: language)
                self.captions = captions
                guard !Task.isCancelled, isCurrent() else { return }
                try await startCapture(captions)
                guard !Task.isCancelled, isCurrent() else { return }
                setStatus(readyStatus(captions.language))
                try await captions.run()
                if !Task.isCancelled, isCurrent() {
                    setStatus(String(localized: "Warm captions stopped"))
                }
            } catch {
                if !Task.isCancelled, isCurrent() {
                    setStatus(String(localized: "Warm captions unavailable: \(error.localizedDescription)"))
                }
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }
}
