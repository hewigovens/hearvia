import Foundation
@testable import HearviaEngines
import Testing

@Test func parsesTranslationEvents() {
    let delta = #"{"type":"session.output_transcript.delta","delta":"你好","elapsed_ms":1200}"#
    guard case let .translationDelta(text, ms) = OpenAIRealtimeClient.parse(Data(delta.utf8)) else { Issue.record()
        return
    }
    #expect(text == "你好" && ms == 1200)
    let error = #"{"type":"error","error":{"type":"invalid_request_error","code":"invalid_event","message":"bad"}}"#
    #expect(OpenAIRealtimeClient.parse(Data(error.utf8)) == .serverError(code: "invalid_event", message: "bad", fatal: false))
    let rejected = #"{"type":"error","error":{"type":"invalid_request_error","code":"invalid_api_key","message":"Incorrect API key"}}"#
    #expect(OpenAIRealtimeClient.parse(Data(rejected.utf8)) == .serverError(code: "invalid_api_key", message: "Incorrect API key", fatal: true))
}

@Test func reducesRoomNoiseOnlyWhenAsked() {
    func noiseReduction(_ configuration: OpenAIRealtimeConfiguration) -> Any? {
        let session = configuration.sessionUpdate["session"] as? [String: Any]
        return ((session?["audio"] as? [String: Any])?["input"] as? [String: Any])?["noise_reduction"]
    }
    #expect(noiseReduction(OpenAIRealtimeConfiguration(targetLanguage: "zh")) is NSNull)
    let reduced = noiseReduction(OpenAIRealtimeConfiguration(targetLanguage: "zh", reducesRoomNoise: true)) as? [String: String]
    #expect(reduced == ["type": "far_field"])
}
