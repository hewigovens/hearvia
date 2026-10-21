import HearviaCore
@testable import HearviaEngines
import Testing

extension StubbedHTTP {
    struct APIKeyCheckTests {
        static let openAIKey = "sk-proj-" + String(repeating: "a1B2", count: 10)
        static let geminiKey = "AIza" + String(repeating: "x", count: 35)

        init() {
            StubServer.responses = []
            StubServer.requests = []
        }

        @Test func turnsAwayMisshapenKeysWithoutAsking() async {
            for (engine, key) in [(EngineKind.realtime, "sk-short"), (.realtime, "AIza" + Self.openAIKey), (.gemini, "AIza-short"),
                                  (.gemini, " " + Self.geminiKey.dropFirst())] {
                await #expect(throws: APIKeyError.malformed(engine)) {
                    try await APIKeyCheck(engine, key: key).verify(session: StubServer.session)
                }
            }
            #expect(StubServer.requests.isEmpty)
        }

        @Test func takesBothGeminiKeyFormats() {
            #expect(APIKeyCheck(.gemini, key: Self.geminiKey).isWellFormed)
            #expect(APIKeyCheck(.gemini, key: "AQ." + String(repeating: "Ab8_x-", count: 8)).isWellFormed)
        }

        @Test func asksEachProviderWithTheKeyInAHeader() async throws {
            StubServer.responses = [(200, "{}"), (200, "{}")]
            try await APIKeyCheck(.realtime, key: Self.openAIKey).verify(session: StubServer.session)
            try await APIKeyCheck(.gemini, key: Self.geminiKey).verify(session: StubServer.session)
            let (openAI, gemini) = (StubServer.requests[0], StubServer.requests[1])
            #expect(openAI.url?.absoluteString == "https://api.openai.com/v1/models")
            #expect(openAI.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.openAIKey)")
            #expect(gemini.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models")
            #expect(gemini.value(forHTTPHeaderField: "x-goog-api-key") == Self.geminiKey)
        }

        @Test func tellsARejectedKeyFromAProviderProblem() async {
            StubServer.responses = [(401, "{}"), (400, #"{"error":{"message":"API key not valid."}}"#), (503, "")]
            await #expect(throws: APIKeyError.rejected(.realtime)) {
                try await APIKeyCheck(.realtime, key: Self.openAIKey).verify(session: StubServer.session)
            }
            await #expect(throws: APIKeyError.rejected(.gemini)) {
                try await APIKeyCheck(.gemini, key: Self.geminiKey).verify(session: StubServer.session)
            }
            await #expect(throws: APIKeyError.failed(.realtime, 503)) {
                try await APIKeyCheck(.realtime, key: Self.openAIKey).verify(session: StubServer.session)
            }
        }
    }
}
