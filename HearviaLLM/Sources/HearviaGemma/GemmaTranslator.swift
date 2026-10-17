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
    private let canUseBackgroundGPU: @MainActor @Sendable () -> Bool

    private init(container: ModelContainer, canUseBackgroundGPU: @escaping @MainActor @Sendable () -> Bool) {
        self.container = container
        self.canUseBackgroundGPU = canUseBackgroundGPU
    }

    /// Loads the weights from `TranslateGemma.directory` (download them first).
    public static func load(canUseBackgroundGPU: @escaping @MainActor @Sendable () -> Bool = { false }) async throws -> GemmaTranslator {
        try await checkGPUAccess(canUseBackgroundGPU)
        guard TranslateGemma.isDownloaded else { throw GemmaError.notDownloaded }
        guard TranslateGemma.hasFreeMemory else { throw GemmaError.notEnoughMemory }
        // MLX keeps freed GPU buffers for reuse; one sentence at a time doesn't need that, and iOS counts it.
        Memory.cacheLimit = 32 * 1024 * 1024
        let configuration = ModelConfiguration(directory: TranslateGemma.directory, extraEOSTokens: ["<end_of_turn>"])
        do {
            let container = try await withError {
                try await LLMModelFactory.shared.loadContainer(from: LocalWeights(), using: TransformersLoader(), configuration: configuration)
            }
            return GemmaTranslator(container: container, canUseBackgroundGPU: canUseBackgroundGPU)
        } catch let MLXError.caught(message) where message.contains("BackgroundExecutionNotPermitted") {
            throw GemmaError.inBackground
        }
    }

    /// Greedy translation of `text` from `source` to `target` (language codes such as "en", "zh").
    public func translate(_ text: String, from source: String, to target: String) async throws -> String {
        try await Self.checkGPUAccess(canUseBackgroundGPU)
        let prompt = Self.prompt(text, from: source, to: target)
        // A translation rarely needs more than ~3 tokens per source character; the cap only stops runaway output.
        let parameters = GenerateParameters(maxTokens: max(32, text.count * 3), temperature: 0)
        let canUseBackgroundGPU = canUseBackgroundGPU
        do {
            // MLX's default error handler ends the process; this makes a failed GPU command buffer a Swift error.
            return try await withError {
                try await container.perform { context in
                    try await Self.checkGPUAccess(canUseBackgroundGPU)
                    let input = LMInput(tokens: MLXArray(context.tokenizer.encode(text: prompt, addSpecialTokens: false)))
                    let iterator = try TokenIterator(input: input, model: context.model, parameters: parameters)
                    let (generations, task) = MLXLMCommon.generateTask(promptTokenCount: input.text.tokens.size,
                                                                       modelConfiguration: context.configuration,
                                                                       tokenizer: context.tokenizer, iterator: iterator)
                    var output = ""
                    do {
                        for await generation in generations {
                            try await Self.checkGPUAccess(canUseBackgroundGPU)
                            output += generation.chunk ?? ""
                        }
                    } catch {
                        task.cancel()
                        await task.value // Keep MLX's error handler installed until GPU work has stopped.
                        throw error
                    }
                    await task.value
                    try await Self.checkGPUAccess(canUseBackgroundGPU)
                    return output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch let MLXError.caught(message) where message.contains("BackgroundExecutionNotPermitted") {
            throw GemmaError.inBackground // Went to the background mid-sentence.
        }
    }

    @MainActor private static func checkGPUAccess(_ canUseBackgroundGPU: @MainActor @Sendable () -> Bool) throws {
        try Task.checkCancellation()
        #if os(iOS)
            if UIApplication.shared.applicationState == .background, !canUseBackgroundGPU() {
                throw GemmaError.inBackground
            }
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
