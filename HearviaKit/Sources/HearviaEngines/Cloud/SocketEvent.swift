import Foundation

public enum SocketEvent: Sendable, Equatable {
    /// The server accepted the session. `expiresAt` is when the provider will end the connection.
    case sessionStarted(id: String, expiresAt: Date?)
    case expiring(at: Date)
    /// Append-only source-language text (only when source transcription is on).
    case sourceDelta(String)
    case translationDelta(String, elapsedMs: Int?)
    /// `fatal` errors (a rejected key, no credit) stop the engine instead of reconnecting.
    case serverError(code: String, message: String, fatal: Bool)
    case closed(reason: String?)
}
