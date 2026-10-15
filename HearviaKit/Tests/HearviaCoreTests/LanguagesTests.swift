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

@Test func realtimeTargetFallsBackToEnglish() {
    #expect(Languages.realtimeTarget(for: "ja") == "ja")
    #expect(Languages.realtimeTarget(for: "nl") == "en")
}

@Test func thaiJoinsWithoutSpaces() {
    #expect(SubtitleText.join("สวัสดี", "ครับ", language: "th") == "สวัสดีครับ")
}
