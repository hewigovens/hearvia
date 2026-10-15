import Foundation
import HearviaCore

/// One run of a pipeline that turns 200 ms PCM16 chunks into subtitle text.
/// An engine instance is used for a single run: start it once, stop it once, then drop it.
@MainActor
public protocol TranslationEngine: AnyObject {
    /// Everything the engine reports. Finishes when the engine stops or fails.
    var updates: AsyncStream<EngineUpdate> { get }

    /// Starts consuming `audio`. Failures arrive as `.failed` on `updates`.
    func start(audio: AsyncStream<Data>) async

    /// Switches the subtitle language in place. Returns false when the engine must be restarted instead.
    func setTargetLanguage(_ language: String) async -> Bool

    func stop() async
}

/// What a running engine reports to the session that owns it.
public enum EngineUpdate: Equatable, Sendable {
    case status(TranslatorStatus)
    /// The full current subtitle text (bounded), replacing the previous one.
    case text(source: String, translation: String)
    /// A finished sentence for the transcript. `source` is empty when there is no separate original.
    case sentence(source: String, translation: String)
    /// One audio chunk reached the engine.
    case audioConsumed
    /// A recoverable error to show; the engine keeps running.
    case problem(String)
    /// The engine gave up; `updates` finishes after this.
    case failed(String)
    case log(String, [String: String])
}
