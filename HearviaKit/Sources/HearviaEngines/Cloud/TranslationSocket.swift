import Foundation

public protocol TranslationSocket: AnyObject, Sendable {
    var events: AsyncStream<SocketEvent> { get }
    func connect() async throws
    /// One 200 ms PCM16 24 kHz mono chunk; the client converts it to what its provider expects.
    func append(_ chunk: Data) async throws
    /// Returns false when the provider fixes the language for a whole session; the engine then opens a new one.
    func setTargetLanguage(_ language: String) async throws -> Bool
    func close() async
    func cancel() async
}
