import Foundation

public enum TranslationEvent: Sendable {
    case sessionCreated(id: String, expiresAt: Date?)
    case sessionUpdated
    /// Append-only source-language text (only when input transcription is configured).
    case sourceDelta(String, elapsedMs: Int?)
    /// Append-only translated text.
    case translationDelta(String, elapsedMs: Int?)
    /// Translated speech; subtitles-only clients ignore it but it is still billed.
    case audioDelta(bytes: Int, elapsedMs: Int?)
    case serverError(type: String, code: String?, message: String)
    case closed(reason: String?)
}
