import Translation

/// Owns a non-Sendable TranslationSession for one on-device run.
actor OnDeviceTextTranslator {
    /// `TranslationSession` is not Sendable and its `translate` is `@concurrent` (iOS/macOS 27 SDK), so a plain
    /// actor property can't be passed to it. `OnDeviceEngine` awaits each request before sending the next one.
    private nonisolated(unsafe) let session: TranslationSession

    let strategy: String

    init(source: String, target: String) async throws {
        guard let strategy = await OnDeviceModels.installedStrategy(from: source, to: target) else {
            throw await OnDeviceModels.translation(from: source, to: target) == .unsupported
                ? OnDeviceError.translationUnsupported(source, target) : OnDeviceError.translationNotInstalled(source, target)
        }
        self.strategy = strategy == .lowLatency ? "low-latency" : "standard"
        session = TranslationSession(installedSource: OnDeviceModels.translationLanguage(source),
                                     target: OnDeviceModels.translationLanguage(target), preferredStrategy: strategy)
    }

    func translate(_ text: String) async throws -> String {
        try await session.translate(text).targetText
    }
}
