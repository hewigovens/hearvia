import Foundation
import HearviaCore

/// A cloud translator key, checked before it's saved and at launch: its shape, then a free request that lists the provider's models.
public struct APIKeyCheck: Sendable {
    public let engine: EngineKind
    public let key: String

    public init(_ engine: EngineKind, key: String) {
        self.engine = engine
        self.key = key
    }

    public var isWellFormed: Bool {
        guard key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }) else { return false }
        return switch engine {
        case .realtime: key.hasPrefix("sk-") && key.count >= 40
        case .gemini: key.count >= 30 // Older keys start with AIza, newer ones with AQ.
        case .onDevice, .local: false
        }
    }

    public func verify(session: URLSession = .shared) async throws(APIKeyError) {
        guard isWellFormed else { throw .malformed(engine) }
        var request = URLRequest(url: modelsURL, timeoutInterval: 15)
        // In a header, not the URL, so the key stays out of logs and caches.
        if engine == .gemini {
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        } else {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw .unreachable(engine, error.localizedDescription)
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200 ..< 300: return
        case 400, 401, 403: throw .rejected(engine) // Gemini answers 400 for a key it doesn't know.
        case let status: throw .failed(engine, status)
        }
    }

    private var modelsURL: URL {
        engine == .gemini ? URL(string: "https://generativelanguage.googleapis.com/v1beta/models")! : URL(string: "https://api.openai.com/v1/models")!
    }
}

public enum APIKeyError: LocalizedError, Equatable {
    case malformed(EngineKind)
    case rejected(EngineKind)
    case unreachable(EngineKind, String)
    case failed(EngineKind, Int)

    public var errorDescription: String? {
        switch self {
        case .malformed(.gemini): String(localized: "That isn't a Gemini key. Copy the whole key from aistudio.google.com.")
        case .malformed: String(localized: "That isn't an OpenAI key. They start with sk-.")
        case let .rejected(engine): String(localized: "\(engine.title) rejected this key.")
        case let .unreachable(engine, reason): String(localized: "Can't reach \(engine.title) to check the key: \(reason)")
        case let .failed(engine, status): String(localized: "\(engine.title) answered \(status) while checking the key. Try again later.")
        }
    }
}
