import Foundation
@testable import HearviaEngines
import Testing

struct GeminiLiveClientTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    private func parse(_ json: String) -> [SocketEvent] {
        GeminiLiveClient.parse(Data(json.utf8), receivedAt: now)
    }

    @Test func setupCompleteStartsASessionThatEndsWithTheConnection() {
        #expect(parse(#"{"setupComplete":{}}"#)
            == [.sessionStarted(id: "", expiresAt: now.addingTimeInterval(GeminiLiveConfiguration.connectionLifetime))])
    }

    @Test func goAwayMovesTheExpiry() {
        #expect(parse(#"{"goAway":{"timeLeft":"12.5s"}}"#) == [.expiring(at: now.addingTimeInterval(12.5))])
    }

    @Test func oneMessageCarriesBothTranscriptsAndAudio() {
        let message = #"""
        {"serverContent":{"inputTranscription":{"text":"Good evening","languageCode":"en"},
         "outputTranscription":{"text":"晚上好","languageCode":"zh-Hans"},
         "modelTurn":{"parts":[{"inlineData":{"mimeType":"audio/pcm;rate=24000","data":"AAAAAA=="}}]}}}
        """#
        #expect(parse(message) == [.sourceDelta("Good evening", elapsedMs: nil), .translationDelta("晚上好", elapsedMs: nil),
                                   .audioDelta(bytes: 6, elapsedMs: nil)])
        #expect(parse(#"{"serverContent":{"turnComplete":true}}"#).isEmpty)
    }

    /// The live service rejects transcript settings inside `generationConfig` (close 1007), whatever the guide's example shows.
    @Test func setupPutsTranslationInGenerationConfigAndTranscriptsBesideIt() throws {
        let setup = try #require(GeminiLiveConfiguration(targetLanguage: "zh").setupMessage["setup"] as? [String: Any])
        #expect(setup["model"] as? String == "models/gemini-3.5-live-translate-preview")
        let generation = try #require(setup["generationConfig"] as? [String: Any])
        let translation = try #require(generation["translationConfig"] as? [String: Any])
        #expect(translation["targetLanguageCode"] as? String == "zh-Hans")
        #expect(setup["inputAudioTranscription"] != nil && setup["outputAudioTranscription"] != nil)
        #expect(generation["inputAudioTranscription"] == nil && generation["outputAudioTranscription"] == nil)

        let quiet = GeminiLiveConfiguration(targetLanguage: "ja", transcribesSource: false).setupMessage
        #expect((quiet["setup"] as? [String: Any])?["inputAudioTranscription"] == nil)
    }

    @Test func downsamplesThreeSamplesToTwo() {
        let input: [Int16] = [100, 200, 400, -300, -100, 500]
        let output = GeminiLiveClient.downsample(input.withUnsafeBytes { Data($0) })
        let samples = output.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        #expect(samples == [100, 300, -300, 200])
    }

    @Test func rejectedKeysAndQuotaAreFatal() {
        #expect(GeminiLiveClient.isFatal("API key not valid. Please pass a valid API key."))
        #expect(GeminiLiveClient.isFatal("RESOURCE_EXHAUSTED: quota exceeded"))
        #expect(!GeminiLiveClient.isFatal("Internal error encountered."))
    }
}
