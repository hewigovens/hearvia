import Foundation

/// One transcription update: the in-progress (volatile) text, or a finished segment.
struct SpeechResult: Sendable {
    let text: String
    let isFinal: Bool
}

/// Speech-to-text fed with 200 ms PCM16 chunks. `OnDeviceSpeech` in the app; a scripted fake in tests.
protocol SpeechInput: AnyObject, Sendable {
    var results: AsyncThrowingStream<SpeechResult, Error> { get }
    /// Call from one task at a time.
    func append(_ chunk: Data) throws
    func finish() async
}

/// What the on-device engine needs for one run, loaded before it starts listening.
struct OnDeviceModelSet: Sendable {
    let speech: any SpeechInput
    /// nil when the spoken and subtitle languages are the same.
    let translate: (@Sendable (String) async throws -> String)?
    /// Translation model in use, for logs.
    let strategy: String
}
