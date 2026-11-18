@testable import HearviaEngines
import Testing

@Test func warmWindowRevisesDraftsAndDropsExpiredSpeech() {
    var window = WarmCaptionWindow()
    window.replace(from: 0, with: [.init(text: "old", start: 0, end: 1), .init(text: " a", start: 2, end: 3),
                                   .init(text: " draft", start: 4, end: 5)], now: 5)
    window.replace(from: 4, with: [.init(text: " correction", start: 4, end: 5)], now: 6)
    #expect(window.words.map(\.text) == [" a", " correction"])
    window.expire(now: 11)
    #expect(window.words.isEmpty)
    window.replace(from: 0, with: [.init(text: "late result", start: 4, end: 5)], now: 12)
    #expect(window.words.isEmpty)
}
