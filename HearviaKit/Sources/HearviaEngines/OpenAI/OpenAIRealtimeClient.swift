import Foundation

public actor OpenAIRealtimeClient: TranslationSocket {
    public nonisolated let events: AsyncStream<SocketEvent>
    private let continuation: AsyncStream<SocketEvent>.Continuation
    private let configuration: OpenAIRealtimeConfiguration
    private let apiKey: String
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var finished = false
    private var closeReason: String?

    public init(configuration: OpenAIRealtimeConfiguration, apiKey: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.session = session
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    public func connect() async throws {
        var components = URLComponents(url: configuration.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "model", value: configuration.model)]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 16 * 1024 * 1024
        self.task = task
        task.resume()
        try await send(sessionUpdate())
        Task { await self.receiveLoop() }
    }

    public func append(_ chunk: Data) async throws {
        try await send(["type": "session.input_audio_buffer.append", "audio": chunk.base64EncodedString()])
    }

    public func setTargetLanguage(_ language: String) async throws -> Bool {
        try await send(["type": "session.update", "session": ["audio": ["output": ["language": language]]]])
        return true
    }

    /// Graceful close: the server flushes pending output, then sends `session.closed`.
    public func close() async {
        try? await send(["type": "session.close"])
    }

    public func cancel() {
        task?.cancel(with: .goingAway, reason: nil)
        finish(reason: "cancelled")
    }

    private func sessionUpdate() -> [String: Any] {
        var input: [String: Any] = [:]
        input["transcription"] = configuration.sourceTranscriptionModel.map { ["model": $0] } ?? NSNull()
        input["noise_reduction"] = NSNull()
        return ["type": "session.update",
                "session": ["audio": ["input": input, "output": ["language": configuration.targetLanguage]]]]
    }

    private func send(_ object: [String: Any]) async throws {
        guard let task, !finished else {
            throw URLError(.networkConnectionLost, userInfo: [NSLocalizedDescriptionKey: closeReason ?? "Translation socket is closed"])
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveLoop() async {
        while let task, !finished {
            do {
                let message = try await task.receive()
                let data: Data
                switch message {
                case let .string(s): data = Data(s.utf8)
                case let .data(d): data = d
                @unknown default: continue
                }
                if let event = Self.parse(data) {
                    continuation.yield(event)
                    if case .closed = event {
                        finish(reason: nil)
                        task.cancel(with: .normalClosure, reason: nil)
                    }
                }
            } catch {
                let detail = task.closeCode == .invalid ? error.localizedDescription
                    : "close \(task.closeCode.rawValue) \(task.closeReason.map { String(decoding: $0, as: UTF8.self) } ?? "")"
                finish(reason: detail)
            }
        }
    }

    private func finish(reason: String?) {
        guard !finished else { return }
        finished = true
        closeReason = reason
        if let reason {
            continuation.yield(.closed(reason: reason))
        }
        continuation.finish()
    }

    static func parse(_ data: Data) -> SocketEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        switch type {
        case "session.created":
            let session = json["session"] as? [String: Any]
            let expires = (session?["expires_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            return .sessionStarted(id: session?["id"] as? String ?? "?", expiresAt: expires)
        case "session.input_transcript.delta": return .sourceDelta(json["delta"] as? String ?? "")
        case "session.output_transcript.delta": return .translationDelta(json["delta"] as? String ?? "", elapsedMs: json["elapsed_ms"] as? Int)
        case "session.closed": return .closed(reason: nil)
        case "error":
            let e = json["error"] as? [String: Any]
            let code = e?["code"] as? String ?? e?["type"] as? String ?? "error"
            return .serverError(code: code, message: e?["message"] as? String ?? String(decoding: data, as: UTF8.self),
                                fatal: ["invalid_api_key", "insufficient_quota"].contains(code))
        default: return nil
        }
    }
}
