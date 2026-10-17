import Foundation

struct SpeechResult: Sendable {
    let text: String
    let isFinal: Bool
}

protocol SpeechInput: AnyObject, Sendable {
    var results: AsyncThrowingStream<SpeechResult, Error> { get }
    /// Call from one task at a time.
    func append(_ chunk: Data) throws
    func finish() async
}

struct OnDeviceModelSet: Sendable {
    let speech: any SpeechInput
    /// nil when the spoken and subtitle languages are the same.
    let translate: (@Sendable (String) async throws -> String)?
    let strategy: String
}
