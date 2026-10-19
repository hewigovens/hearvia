import Foundation

/// The target language is fixed per session; audio is sent at the 16 kHz the Live API takes.
public actor GeminiLiveClient: TranslationSocket {
    public nonisolated let events: AsyncStream<SocketEvent>
    private let continuation: AsyncStream<SocketEvent>.Continuation
    private let configuration: GeminiLiveConfiguration
    private let apiKey: String
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var finished = false
    private var closeReason: String?

    public init(configuration: GeminiLiveConfiguration, apiKey: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.session = session
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    public func connect() async throws {
        var components = URLComponents(url: configuration.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        let task = session.webSocketTask(with: components.url!)
        task.maximumMessageSize = 16 * 1024 * 1024
        self.task = task
        task.resume()
        try await send(configuration.setupMessage)
        Task { await self.receiveLoop() }
    }

    public func append(_ chunk: Data) async throws {
        try await send(["realtimeInput": ["audio": ["mimeType": "audio/pcm;rate=16000",
                                                    "data": Self.downsample(chunk).base64EncodedString()]]])
    }

    public func setTargetLanguage(_: String) async throws -> Bool {
        false
    }

    /// Ends the audio stream so the server translates the last words; the engine cancels the socket after a grace period.
    public func close() async {
        try? await send(["realtimeInput": ["audioStreamEnd": true]])
    }

    public func cancel() {
        task?.cancel(with: .goingAway, reason: nil)
        finish(reason: "cancelled")
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
                for event in Self.parse(data, receivedAt: Date()) {
                    continuation.yield(event)
                }
            } catch {
                // Google reports a rejected key or an exhausted quota as the close reason.
                let reason = task.closeReason.map { String(decoding: $0, as: UTF8.self) } ?? ""
                if !reason.isEmpty {
                    continuation.yield(.serverError(code: "close \(task.closeCode.rawValue)", message: reason, fatal: Self.isFatal(reason)))
                }
                finish(reason: task.closeCode == .invalid ? error.localizedDescription : "close \(task.closeCode.rawValue) \(reason)")
            }
        }
    }

    private func finish(reason: String?) {
        guard !finished else { return }
        finished = true
        closeReason = reason
        continuation.yield(.closed(reason: reason))
        continuation.finish()
    }

    /// One server message can carry both the original text and the translation; translated audio is ignored.
    static func parse(_ data: Data, receivedAt now: Date) -> [SocketEvent] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        if json["setupComplete"] != nil {
            return [.sessionStarted(id: "", expiresAt: now.addingTimeInterval(GeminiLiveConfiguration.connectionLifetime))]
        }
        if let goAway = json["goAway"] as? [String: Any] {
            return [.expiring(at: now.addingTimeInterval(seconds(goAway["timeLeft"]) ?? 0))]
        }
        guard let content = json["serverContent"] as? [String: Any] else { return [] }
        var events: [SocketEvent] = []
        if let text = (content["inputTranscription"] as? [String: Any])?["text"] as? String, !text.isEmpty {
            events.append(.sourceDelta(text))
        }
        if let text = (content["outputTranscription"] as? [String: Any])?["text"] as? String, !text.isEmpty {
            events.append(.translationDelta(text, elapsedMs: nil))
        }
        return events
    }

    static func seconds(_ value: Any?) -> TimeInterval? {
        (value as? String).flatMap { TimeInterval($0.trimmingCharacters(in: CharacterSet(charactersIn: "s"))) }
    }

    static func isFatal(_ reason: String) -> Bool {
        ["API key", "API_KEY", "PERMISSION_DENIED", "RESOURCE_EXHAUSTED", "quota"].contains { reason.localizedCaseInsensitiveContains($0) }
    }

    /// 24 kHz → 16 kHz PCM16: every 3 samples become 2 (the first, then the midpoint of the other two).
    static func downsample(_ chunk: Data) -> Data {
        chunk.withUnsafeBytes { raw in
            func sample(_ index: Int) -> Int32 {
                Int32(raw.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))
            }
            var output: [Int16] = []
            output.reserveCapacity(raw.count / 3)
            for index in stride(from: 0, to: raw.count / 2 - 2, by: 3) {
                output.append(Int16(sample(index)))
                output.append(Int16((sample(index + 1) + sample(index + 2)) / 2))
            }
            return output.withUnsafeBytes { Data($0) }
        }
    }
}
