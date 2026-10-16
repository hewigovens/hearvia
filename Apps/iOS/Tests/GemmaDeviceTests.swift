import HearviaGemma
import os
import XCTest

/// TranslateGemma inside the app's process on a real iPhone, where the memory limit applies. Skipped until the model
/// is in the app's container (Settings → Translators, or copy it over as agents/run-debug.md describes).
final class GemmaDeviceTests: XCTestCase {
    func testTranslatesSentencesWithinTheMemoryLimit() async throws {
        try XCTSkipUnless(TranslateGemma.isDownloaded, "TranslateGemma isn't on this device")
        print("gemma_memory free_before_load_mb=\(os_proc_available_memory() >> 20)")
        var start = ContinuousClock.now
        let translator = try await GemmaTranslator.load()
        print("gemma_load seconds=\(start.duration(to: .now)) free_after_load_mb=\(os_proc_available_memory() >> 20)")
        _ = try await translator.translate("Hello.", from: "en", to: "zh")
        for sentence in ["Researchers followed 200 volunteers for six months.",
                         "Turning off screens an hour before bed also helped, but the effect was smaller than expected.",
                         "So for the next quarter we'll focus on onboarding, and the pricing page goes out next week."] {
            start = ContinuousClock.now
            let translation = try await translator.translate(sentence, from: "en", to: "zh")
            print("gemma_sentence seconds=\(start.duration(to: .now)) free_mb=\(os_proc_available_memory() >> 20) \(translation)")
            XCTAssertFalse(translation.isEmpty)
        }
    }
}
