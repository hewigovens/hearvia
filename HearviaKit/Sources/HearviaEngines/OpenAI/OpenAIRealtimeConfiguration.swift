import Foundation

public struct OpenAIRealtimeConfiguration: Sendable {
    public var targetLanguage: String
    var sourceTranscriptionModel: String?
    public var model = "gpt-realtime-translate"
    public var endpoint = URL(string: "wss://api.openai.com/v1/realtime/translations")!

    static let defaultTranscriptionModel = "gpt-realtime-whisper"

    /// `transcribesSource: false` turns off the original-language text, which is billed separately.
    public init(targetLanguage: String, transcribesSource: Bool = true) {
        self.targetLanguage = targetLanguage
        sourceTranscriptionModel = transcribesSource ? Self.defaultTranscriptionModel : nil
    }
}
