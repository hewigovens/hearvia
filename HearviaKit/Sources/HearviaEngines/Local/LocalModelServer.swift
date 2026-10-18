import Foundation
import HearviaCore

public struct LocalModelServer: Sendable, Equatable {
    public var baseURL: String
    public var apiKey: String

    public init(baseURL: String, apiKey: String = "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    /// Unsloth Studio also needs its API key. On another machine, use its address instead of localhost and start the server so it listens on the network.
    public static let presets: [(name: String, baseURL: String)] = [
        ("Ollama", "http://localhost:11434/v1"),
        ("LM Studio", "http://localhost:1234/v1"),
        ("Unsloth Studio", "http://localhost:8888/v1"),
        ("llama.cpp server", "http://localhost:8080/v1")
    ]

    public func models(session: URLSession = .shared) async throws -> [String] {
        let data = try await send(request(path: "models"), session: session)
        let list = try JSONDecoder().decode(ModelList.self, from: data)
        return list.data.map(\.id).sorted()
    }

    public func translate(_ text: String, from source: String, to target: String, model: String,
                          session: URLSession = .shared) async throws -> String {
        var request = try request(path: "chat/completions")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // One user message: translation models such as Index-Translate don't take a system prompt.
        request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: [
            .init(role: "user", content: Self.prompt(text, from: source, to: target, model: model))
        ]))
        let data = try await send(request, session: session)
        let reply = try JSONDecoder().decode(ChatReply.self, from: data)
        return Self.cleaned(reply.choices.first?.message.content ?? "")
    }

    /// nil when the spoken and subtitle languages are the same.
    func translator(from source: String, to target: String, model: String) -> Translate? {
        guard source != target else { return nil }
        return { [self] text in try await translate(text, from: source, to: target, model: model) }
    }

    static func prompt(_ text: String, from source: String, to target: String, model: String) -> String {
        if model.localizedCaseInsensitiveContains("index-translate") {
            // The prompt from the Index-Translate model card, with the target named in Chinese.
            let name = Locale(identifier: "zh-Hans").localizedString(forIdentifier: target) ?? LanguageName.english(target)
            return "请将以下文本翻译为\(name)，直接输出翻译结果，不要进行任何解释。\n\n\(text)"
        }
        let from = LanguageName.english(source), to = LanguageName.english(target)
        return "Translate this live speech subtitle from \(from) to \(to). Reply with only the \(to) translation: no notes, "
            + "quotes or alternatives. Translate every word, including names and numbers, but keep their meaning exact.\n\n\(text)"
    }

    /// Drops the reasoning some models print before the answer.
    static func cleaned(_ reply: String) -> String {
        var text = reply
        if let end = text.range(of: "</think>") {
            text = String(text[end.upperBound...])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func request(path: String) throws -> URLRequest {
        let base = baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(path)"), url.scheme == "http" || url.scheme == "https" else {
            throw LocalModelError.badAddress(baseURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LocalModelError.unreachable(baseURL, error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw LocalModelError.rejected(http.statusCode, String(decoding: data.prefix(300), as: UTF8.self))
        }
        return data
    }

    private struct ModelList: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        var temperature = 0
        var stream = false
        /// Turns off thinking on servers that pass it to the chat template (llama.cpp, vLLM); others ignore it.
        var chatTemplateKwargs = ["enable_thinking": false]

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, stream
            case chatTemplateKwargs = "chat_template_kwargs"
        }
    }

    private struct ChatReply: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }

        let choices: [Choice]
    }
}

public enum LocalModelError: LocalizedError, Equatable {
    case badAddress(String)
    case unreachable(String, String)
    case rejected(Int, String)
    case noModel

    public var errorDescription: String? {
        switch self {
        case let .badAddress(address): String(localized: "\"\(address)\" isn't a server address. Use one like http://localhost:11434/v1.")
        case let .unreachable(address, reason):
            String(localized: "Can't reach the local model server at \(address): \(reason) If it's on another machine, allow Hearvia under Privacy & Security → Local Network.")
        case let .rejected(status, body): String(localized: "The local model server answered \(status)") + (body.isEmpty ? "" : ": \(body)")
        case .noModel: String(localized: "Choose a local model in Settings → Translators.")
        }
    }
}
