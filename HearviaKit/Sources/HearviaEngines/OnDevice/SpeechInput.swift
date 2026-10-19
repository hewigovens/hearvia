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
