import Foundation

/// The Realtime translation socket as `RealtimeEngine` uses it: `RealtimeTranslationClient` in the apps, a fake in tests.
public protocol RealtimeSocket: AnyObject, Sendable {
    var events: AsyncStream<RealtimeEvent> { get }
    func connect() async throws
    func append(_ chunk: Data) async throws
    func setTargetLanguage(_ language: String) async throws
    /// Asks the server to flush pending output and then close.
    func close() async
    func cancel() async
}
