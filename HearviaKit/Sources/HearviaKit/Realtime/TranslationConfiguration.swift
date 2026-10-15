import Foundation

public struct TranslationConfiguration: Sendable {
    public var targetLanguage: String
    public var sourceTranscriptionModel: String?
    public var noiseReduction: String? // "near_field", "far_field" or nil
    public var model = "gpt-realtime-translate"
    public var endpoint = URL(string: "wss://api.openai.com/v1/realtime/translations")!

    public init(targetLanguage: String, sourceTranscriptionModel: String? = "gpt-realtime-whisper", noiseReduction: String? = nil) {
        self.targetLanguage = targetLanguage
        self.sourceTranscriptionModel = sourceTranscriptionModel
        self.noiseReduction = noiseReduction
    }
}
