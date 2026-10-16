import HearviaCore
import HearviaEngines
@testable import HearviaSession
import Testing

@MainActor
final class FakeDownloadable: DownloadableEngine {
    let kind = EngineKind.gemma
    let downloadBytes: Int64 = 1
    let isDownloaded = true
    let progress: Double? = nil
    let failure = ""
    let isSupported: Bool
    private(set) var made: [FakeEngine] = []

    init(supported: Bool = true) {
        isSupported = supported
    }

    func download() async {}
    func remove() {}

    func makeEngine(_ request: EngineRequest) -> any TranslationEngine {
        let engine = FakeEngine(kind: kind, request: request)
        made.append(engine)
        return engine
    }
}

@MainActor
struct DownloadableEngineTests {
    @Test func offeredOnlyWhenTheAppProvidesOneThisDeviceCanRun() {
        #expect(!Harness().translator.engines.contains(.gemma))
        let unsupported = Harness()
        unsupported.downloadable = [FakeDownloadable(supported: false)]
        #expect(!unsupported.translator.engines.contains(.gemma))
        let supported = Harness()
        supported.downloadable = [FakeDownloadable()]
        #expect(supported.translator.engines == [.onDevice, .realtime, .gemini, .gemma])
    }

    @Test func runsTheAppsEngineWithoutAKey() async {
        let harness = Harness(apiKey: nil)
        let gemma = FakeDownloadable()
        harness.downloadable = [gemma]
        await harness.translator.setEngine(.gemma)
        await harness.translator.start()
        #expect(gemma.made.first?.started == true)
        #expect(gemma.made.first?.request.targetLanguage == harness.translator.targetLanguage)
        #expect(harness.engines.isEmpty)
    }
}
