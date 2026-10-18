@testable import HearviaCore
import Testing

@Test func realtimeChoicesAreTheFixedSet() {
    #expect(Languages.choices(for: .realtime, onDevice: ["nl", "en"], including: "en") == Languages.supported)
}

@Test func onDeviceChoicesPutRealtimeLanguagesFirst() {
    let choices = Languages.choices(for: .onDevice, onDevice: ["sv", "nl", "en", "ja"], including: "en")
    #expect(choices.prefix(2) == ["en", "ja"]) // in Languages.supported order
    #expect(Set(choices.dropFirst(2)) == ["sv", "nl"])
}

@Test func onDeviceChoicesFallBackUntilLoaded() {
    #expect(Languages.choices(for: .onDevice, onDevice: [], including: "zh") == Languages.supported)
}

@Test func choicesKeepTheCurrentSelection() {
    #expect(Languages.choices(for: .realtime, onDevice: [], including: "nl").first == "nl")
    #expect(Languages.choices(for: .onDevice, onDevice: ["en"], including: "ko") == ["ko", "en"])
}

@Test func cloudTargetFallsBackToEnglish() {
    #expect(Languages.target("ja", for: .realtime) == "ja")
    #expect(Languages.target("nl", for: .realtime) == "en")
    #expect(Languages.target("nl", for: .gemini) == "nl")
    #expect(Languages.target("yue", for: .gemini) == "en")
}

@Test func geminiChoicesAddItsLanguagesAfterTheCommonOnes() {
    let choices = Languages.choices(for: .gemini, onDevice: [], including: "en")
    #expect(choices.filter { $0 != Languages.traditionalChinese }.prefix(Languages.supported.count) == Languages.supported[...])
    #expect(choices.contains("nl") && choices.contains("sw") && choices.count == Set(choices).count)
}

@Test func thaiJoinsWithoutSpaces() {
    #expect(SubtitleText.join("สวัสดี", "ครับ", language: "th") == "สวัสดีครับ")
}

@Test func traditionalChineseFollowsChineseAndFallsBackToIt() throws {
    let choices = Languages.choices(for: .gemini, onDevice: [], including: "en")
    #expect(try choices[#require(choices.firstIndex(of: "zh")) + 1] == Languages.traditionalChinese)
    #expect(!Languages.choices(for: .realtime, onDevice: [], including: "en").contains(Languages.traditionalChinese))
    #expect(Languages.target(Languages.traditionalChinese, for: .realtime) == "zh")
    #expect(SubtitleText.join("你好", "世界", language: Languages.traditionalChinese) == "你好世界")
    #expect(LanguageName.english(Languages.traditionalChinese) == "Traditional Chinese")
}
