import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers
#if os(iOS)
    import UIKit
#endif

/// Translates text with a downloaded TranslateGemma model on the GPU (MLX). Load once per run; requests are serialised
/// by the model container.
public final class GemmaTranslator: Sendable {
    private let container: ModelContainer

    private init(container: ModelContainer) {
        self.container = container
    }

    /// Loads the weights from `TranslateGemma.directory` (download them first).
    public static func load() async throws -> GemmaTranslator {
        guard TranslateGemma.isDownloaded else { throw GemmaError.notDownloaded }
        guard TranslateGemma.hasFreeMemory else { throw GemmaError.notEnoughMemory }
        // MLX keeps freed GPU buffers for reuse; one sentence at a time doesn't need that, and iOS counts it.
        Memory.cacheLimit = 32 * 1024 * 1024
        let configuration = ModelConfiguration(directory: TranslateGemma.directory, extraEOSTokens: ["<end_of_turn>"])
        let container = try await LLMModelFactory.shared.loadContainer(from: LocalWeights(), using: TransformersLoader(),
                                                                       configuration: configuration)
        return GemmaTranslator(container: container)
    }

    /// Greedy translation of `text` from `source` to `target` (language codes such as "en", "zh").
    public func translate(_ text: String, from source: String, to target: String) async throws -> String {
        // iOS rejects GPU work from background apps; a run that tried anyway fails every token until the length cap.
        if await Self.isInBackground {
            throw GemmaError.inBackground
        }
        let prompt = Self.prompt(text, from: source, to: target)
        // A translation rarely needs more than ~3 tokens per source character; the cap only stops runaway output.
        let parameters = GenerateParameters(maxTokens: max(32, text.count * 3), temperature: 0)
        do {
            // MLX's default error handler ends the process; this makes a failed GPU command buffer a Swift error.
            return try await withError {
                try await container.perform { context in
                    let input = LMInput(tokens: MLXArray(context.tokenizer.encode(text: prompt, addSpecialTokens: false)))
                    var output = ""
                    for await generation in try MLXLMCommon.generate(input: input, parameters: parameters, context: context) {
                        output += generation.chunk ?? ""
                    }
                    return output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch let MLXError.caught(message) where message.contains("BackgroundExecutionNotPermitted") {
            throw GemmaError.inBackground // Went to the background mid-sentence.
        }
    }

    @MainActor private static var isInBackground: Bool {
        #if os(iOS)
            UIApplication.shared.applicationState == .background
        #else
            false
        #endif
    }

    /// TranslateGemma's chat template for one text turn, written out: the Swift Jinja renderer doesn't take its
    /// structured message content.
    static func prompt(_ text: String, from source: String, to target: String) -> String {
        let from = name(source), to = name(target)
        return "<bos><start_of_turn>user\nYou are a professional \(from) (\(source)) to \(to) (\(target)) translator. "
            + "Your goal is to accurately convey the meaning and nuances of the original \(from) text while adhering to "
            + "\(to) grammar, vocabulary, and cultural sensitivities.\nProduce only the \(to) translation, without any "
            + "additional explanations or commentary. Please translate the following \(from) text into \(to):\n\n\n"
            + text.trimmingCharacters(in: .whitespacesAndNewlines) + "<end_of_turn>\n<start_of_turn>model\n"
    }

    /// The English language name the template uses ("zh" → "Chinese").
    static func name(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    }
}

/// The weights are already on disk; loading never downloads.
private struct LocalWeights: Downloader {
    func download(id _: String, revision _: String?, matching _: [String], useLatest _: Bool,
                  progressHandler _: @Sendable @escaping (Progress) -> Void) async throws -> URL {
        TranslateGemma.directory
    }
}

/// swift-transformers tokenizer behind mlx-swift-lm's protocol (what the MLXHuggingFace macros generate).
private struct TransformersLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        try await TokenizerBridge(upstream: AutoTokenizer.from(modelFolder: directory))
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? {
        upstream.bosToken
    }

    var eosToken: String? {
        upstream.eosToken
    }

    var unknownToken: String? {
        upstream.unknownToken
    }

    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
    }
}
