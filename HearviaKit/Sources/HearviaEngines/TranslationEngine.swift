import Foundation
import HearviaCore

/// An engine instance is used for a single run: start it once, stop it once, then drop it.
@MainActor
public protocol TranslationEngine: AnyObject {
    /// Everything the engine reports. Finishes when the engine stops or fails.
    var updates: AsyncStream<EngineUpdate> { get }

    /// Failures arrive as `.failed` on `updates`.
    func start(audio: AsyncStream<Data>) async

    /// Switches the subtitle language in place. Returns false when the engine must be restarted instead.
    func setTargetLanguage(_ language: String) async -> Bool

    /// Off while nothing shows subtitles: only finished sentences, which the transcript needs, are translated.
    func setTranslatesDrafts(_ translates: Bool)

    func stop() async
}

public extension TranslationEngine {
    /// Cloud providers send their own drafts at no extra cost.
    func setTranslatesDrafts(_: Bool) {}
}

public enum EngineUpdate: Equatable, Sendable {
    case status(TranslatorStatus)
    /// The full current subtitle text (bounded), replacing the previous one.
    case text(source: String, translation: String)
    /// A finished sentence for the transcript. `source` is empty when there is no separate original.
    case sentence(source: String, translation: String)
    case audioConsumed
    /// A recoverable error to show; the engine keeps running.
    case problem(String)
    /// The engine gave up; `updates` finishes after this.
    case failed(String)
    case log(String, [String: String])
}
