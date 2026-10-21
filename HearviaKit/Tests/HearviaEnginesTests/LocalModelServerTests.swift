import Foundation
@testable import HearviaEngines
import Testing

extension StubbedHTTP {
    struct LocalModelServerTests {
        init() {
            StubServer.responses = []
            StubServer.requests = []
        }

        @Test func listsModelsWithTheKey() async throws {
            StubServer.responses = [(200, #"{"object":"list","data":[{"id":"qwen3:8b"},{"id":"gemma3:4b"}]}"#)]
            let server = LocalModelServer(baseURL: "http://localhost:8888/v1/", apiKey: "sk-unsloth-test")
            #expect(try await server.models(session: StubServer.session) == ["gemma3:4b", "qwen3:8b"])
            let request = try #require(StubServer.requests.first)
            #expect(request.url?.absoluteString == "http://localhost:8888/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-unsloth-test")
        }

        @Test func translatesOneSentenceGreedily() async throws {
            StubServer.responses = [(200, #"{"choices":[{"message":{"role":"assistant","content":"<think>\nok\n</think>\n\n晚上好。"}}]}"#)]
            let server = LocalModelServer(baseURL: "http://localhost:11434/v1")
            let translation = try await server.translate("Good evening.", from: "en", to: "zh", model: "qwen3:8b", session: StubServer.session)
            #expect(translation == "晚上好。") // The reasoning block is dropped.
            let request = try #require(StubServer.requests.first)
            #expect(request.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
            #expect(body["model"] as? String == "qwen3:8b" && body["temperature"] as? Int == 0 && body["stream"] as? Bool == false)
            #expect((body["chat_template_kwargs"] as? [String: Bool])?["enable_thinking"] == false)
            let messages = try #require(body["messages"] as? [[String: String]])
            #expect(messages.map { $0["role"] } == ["user"])
            #expect(messages[0]["content"]?.contains("from English to Chinese") == true && messages[0]["content"]?.hasSuffix("\n\nGood evening.") == true)
        }

        @Test func usesIndexTranslatesOwnPrompt() {
            #expect(LocalModelServer.prompt("Good evening.", from: "en", to: "ja", model: "Index-Translate-9B")
                == "请将以下文本翻译为日语，直接输出翻译结果，不要进行任何解释。\n\nGood evening.")
        }

        @Test func reportsWhatTheServerSaid() async {
            StubServer.responses = [(404, #"{"error":"model 'nope' not found"}"#)]
            let server = LocalModelServer(baseURL: "http://localhost:11434/v1")
            await #expect(throws: LocalModelError.rejected(404, #"{"error":"model 'nope' not found"}"#)) {
                try await server.translate("Hi", from: "en", to: "ja", model: "nope", session: StubServer.session)
            }
            await #expect(throws: LocalModelError.badAddress("localhost:11434")) {
                try await LocalModelServer(baseURL: "localhost:11434").models(session: StubServer.session)
            }
        }
    }
}
