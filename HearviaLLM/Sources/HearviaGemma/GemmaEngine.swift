import Foundation
import HearviaCore
import HearviaEngines
import HearviaSession
import Observation

/// TranslateGemma as a Hearvia translator: Apple's on-device speech recognition, then TranslateGemma for the text.
/// The model loads at the start of each run and is freed when it stops.
@MainActor @Observable
public final class GemmaEngine: DownloadableEngine {
    public let kind = EngineKind.gemma
    public let downloadBytes = TranslateGemma.downloadBytes
    public private(set) var isDownloaded = TranslateGemma.isDownloaded
    public private(set) var progress: Double?
    public private(set) var failure = ""

    private let canUseBackgroundGPU: @MainActor @Sendable () -> Bool

    public init(canUseBackgroundGPU: @escaping @MainActor @Sendable () -> Bool = { false }) {
        self.canUseBackgroundGPU = canUseBackgroundGPU
    }

    public var isSupported: Bool {
        TranslateGemma.hasDeviceMemory
    }

    public func download() async {
        guard progress == nil else { return }
        progress = 0
        failure = ""
        do {
            try await TranslateGemma.download { [weak self] in self?.progress = $0 }
        } catch {
            failure = error.localizedDescription
        }
        progress = nil
        isDownloaded = TranslateGemma.isDownloaded
    }

    public func remove() {
        do { try TranslateGemma.remove() } catch { failure = error.localizedDescription }
        isDownloaded = TranslateGemma.isDownloaded
    }

    public func makeEngine(_ request: EngineRequest) -> any TranslationEngine {
        let source = request.sourceLanguage, target = request.targetLanguage
        let canUseBackgroundGPU = canUseBackgroundGPU
        return OnDeviceEngine(sourceLanguage: source, targetLanguage: target, translatorName: TranslateGemma.repo) {
            let translator = try await GemmaTranslator.load(canUseBackgroundGPU: canUseBackgroundGPU)
            return { try await translator.translate($0, from: source, to: target) }
        }
    }
}
