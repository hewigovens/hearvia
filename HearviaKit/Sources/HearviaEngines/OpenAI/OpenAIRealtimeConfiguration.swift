import Foundation

public struct OpenAIRealtimeConfiguration: Sendable {
    public var targetLanguage: String
    public var sourceTranscriptionModel: String?
    public var noiseReduction: String? // "near_field", "far_field" or nil
    public var model = "gpt-realtime-translate"
    public var endpoint = URL(string: "wss://api.openai.com/v1/realtime/translations")!

    public static let defaultTranscriptionModel = "gpt-realtime-whisper"

    /// `transcribesSource: false` turns off the original-language text, which is billed separately.
    public init(targetLanguage: String, transcribesSource: Bool = true, noiseReduction: String? = nil) {
        self.targetLanguage = targetLanguage
        sourceTranscriptionModel = transcribesSource ? Self.defaultTranscriptionModel : nil
        self.noiseReduction = noiseReduction
    }
}
