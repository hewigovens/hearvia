import Foundation

public struct OpenAIRealtimeConfiguration: Sendable {
    public var targetLanguage: String
    var sourceTranscriptionModel: String?
    /// Far-field noise reduction suits a microphone in a room; other apps' audio is already clean.
    var reducesRoomNoise: Bool
    public var model = "gpt-realtime-translate"
    public var endpoint = URL(string: "wss://api.openai.com/v1/realtime/translations")!

    static let defaultTranscriptionModel = "gpt-realtime-whisper"

    /// `transcribesSource: false` turns off the original-language text, which is billed separately.
    public init(targetLanguage: String, transcribesSource: Bool = true, reducesRoomNoise: Bool = false) {
        self.targetLanguage = targetLanguage
        sourceTranscriptionModel = transcribesSource ? Self.defaultTranscriptionModel : nil
        self.reducesRoomNoise = reducesRoomNoise
    }

    var sessionUpdate: [String: Any] {
        let input: [String: Any] = ["transcription": sourceTranscriptionModel.map { ["model": $0] } ?? NSNull(),
                                    "noise_reduction": reducesRoomNoise ? ["type": "far_field"] : NSNull()]
        return ["type": "session.update", "session": ["audio": ["input": input, "output": ["language": targetLanguage]]]]
    }
}
