import Translation

/// Translates on one TranslationSession for an on-device run. The session isn't Sendable and its `translate` is
/// `@concurrent` (iOS/macOS 27 SDK), so it lives as a local in one task; only strings cross in and out, one request
/// at a time.
final class OnDeviceTextTranslator: Sendable {
    let strategy: String
    private let requests: AsyncStream<Request>.Continuation

    private struct Request: Sendable {
        let text: String
        let reply: CheckedContinuation<String, Error>
    }

    init(source: String, target: String) async throws {
        guard let strategy = await OnDeviceModels.installedStrategy(from: source, to: target) else {
            throw await OnDeviceModels.translation(from: source, to: target) == .unsupported
                ? OnDeviceError.translationUnsupported(source, target) : OnDeviceError.translationNotInstalled(source, target)
        }
        self.strategy = strategy == .lowLatency ? "low-latency" : "standard"
        let (stream, requests) = AsyncStream<Request>.makeStream()
        self.requests = requests
        let source = OnDeviceModels.translationLanguage(source), target = OnDeviceModels.translationLanguage(target)
        Task {
            let session = TranslationSession(installedSource: source, target: target, preferredStrategy: strategy)
            for await request in stream {
                do {
                    try await request.reply.resume(returning: session.translate(request.text).targetText)
                } catch {
                    request.reply.resume(throwing: error)
                }
            }
        }
    }

    deinit {
        requests.finish() // Ends the task, which frees the session.
    }

    func translate(_ text: String) async throws -> String {
        try await withCheckedThrowingContinuation { requests.yield(Request(text: text, reply: $0)) }
    }
}
