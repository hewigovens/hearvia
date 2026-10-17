import Foundation

struct SpeechResult: Sendable {
    let text: String
    let isFinal: Bool
    /// The detected language when the run started on Auto.
    var language = ""
    /// How Auto chose `language`, on the first result after each decision; for logs.
    var detection = ""
}

protocol SpeechInput: AnyObject, Sendable {
    var results: AsyncThrowingStream<SpeechResult, Error> { get }
    /// Call from one task at a time.
    func append(_ chunk: Data) throws
    func finish() async
}

typealias Translate = @Sendable (String) async throws -> String

struct OnDeviceModelSet: Sendable {
    let speech: any SpeechInput
    /// nil when the spoken and subtitle languages are the same.
    let translate: Translate?
    let strategy: String
    /// On Auto, builds `translate` once the spoken language is known; nil from it means no translation is needed.
    var translator: (@Sendable (_ source: String) async throws -> Translate?)?
}
