import Foundation

/// Session settings for Gemini Live translation.
public struct GeminiLiveConfiguration: Sendable {
    public var targetLanguage: String
    public var transcribesSource: Bool
    public var model = "gemini-3.5-live-translate-preview"
    public var endpoint = URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent")!

    /// Google ends a Live connection after about ten minutes; the engine rotates to a new one before then.
    public static let connectionLifetime: TimeInterval = 600

    public init(targetLanguage: String, transcribesSource: Bool = true) {
        self.targetLanguage = targetLanguage
        self.transcribesSource = transcribesSource
    }

    /// The first message on the socket. Speech already in the target language is echoed rather than skipped,
    /// so it still gets subtitles; the echoed audio is discarded anyway.
    var setupMessage: [String: Any] {
        var setup: [String: Any] = [
            "model": "models/\(model)",
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "translationConfig": ["targetLanguageCode": Self.languageCode(targetLanguage), "echoTargetLanguage": true]
            ],
            "outputAudioTranscription": [String: Any]()
        ]
        if transcribesSource {
            setup["inputAudioTranscription"] = [String: Any]()
        }
        return ["setup": setup]
    }

    /// Gemini names the script for Chinese and the region for Portuguese; the app's other codes are what it expects.
    static func languageCode(_ code: String) -> String {
        switch code {
        case "zh": "zh-Hans"
        case "pt": "pt-BR"
        default: code
        }
    }
}
