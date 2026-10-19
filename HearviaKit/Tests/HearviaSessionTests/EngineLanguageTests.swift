import Foundation
import HearviaCore
@testable import HearviaSession
import Testing

@MainActor
struct EngineLanguageTests {
    @Test func switchingToRealtimeDropsAnOnDeviceOnlyLanguage() async {
        let harness = Harness()
        let translator = harness.translator
        await translator.setEngine(.onDevice)
        await translator.setTargetLanguage("nl")
        await translator.setEngine(.realtime)
        #expect(translator.targetLanguage == "en")
    }

    @Test func switchingToGeminiKeepsALanguageOnlyGeminiOffers() async {
        let harness = Harness()
        let translator = harness.translator
        await translator.setEngine(.onDevice)
        await translator.setTargetLanguage("nl")
        await translator.setEngine(.gemini)
        #expect(translator.targetLanguage == "nl")
        await translator.setTargetLanguage("yue")
        await translator.setEngine(.realtime)
        await translator.setEngine(.gemini)
        #expect(translator.targetLanguage == "en")
    }

    @Test func switchingToRealtimeKeepsASupportedLanguage() async {
        let harness = Harness()
        let translator = harness.translator
        await translator.setEngine(.onDevice)
        await translator.setTargetLanguage("ja")
        await translator.setEngine(.realtime)
        #expect(translator.targetLanguage == "ja")
    }

    @Test func swapTradesSpokenAndSubtitleLanguages() async {
        let translator = Harness().translator
        await translator.setEngine(.onDevice)
        await translator.setSourceLanguage("ja")
        await translator.setTargetLanguage(Languages.traditionalChinese)
        await translator.swapLanguages()
        #expect(translator.sourceLanguage == "zh" && translator.targetLanguage == "ja") // Traditional Chinese is spoken as "zh"
        await translator.setSourceLanguage("") // Auto has nothing to swap
        await translator.swapLanguages()
        #expect(translator.sourceLanguage.isEmpty && translator.targetLanguage == "ja")
        await translator.setSourceLanguage("en")
        await translator.setEngine(.realtime) // detects the spoken language itself
        #expect(!translator.canSwapLanguages)
    }
}
