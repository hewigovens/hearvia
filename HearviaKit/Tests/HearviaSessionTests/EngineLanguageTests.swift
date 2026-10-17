import Foundation
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
}
