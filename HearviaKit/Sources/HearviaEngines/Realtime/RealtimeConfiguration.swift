import Foundation

/// Session settings for the Realtime translation socket.
public struct RealtimeConfiguration: Sendable {
    public var targetLanguage: String
    public var sourceTranscriptionModel: String?
    public var noiseReduction: String? // "near_field", "far_field" or nil
    public var model = "gpt-realtime-translate"
    public var endpoint = URL(string: "wss://api.openai.com/v1/realtime/translations")!

    public static let defaultTranscriptionModel = "gpt-realtime-whisper"

    /// `sourceTranscriptionModel: nil` turns off the original-language text, which is billed separately.
    public init(targetLanguage: String, sourceTranscriptionModel: String? = defaultTranscriptionModel, noiseReduction: String? = nil) {
        self.targetLanguage = targetLanguage
        self.sourceTranscriptionModel = sourceTranscriptionModel
        self.noiseReduction = noiseReduction
    }
}
