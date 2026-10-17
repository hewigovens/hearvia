import Foundation
@testable import HearviaCore
import Testing

@Test func joinsWithSpacesExceptInUnspacedLanguages() {
    #expect(SubtitleText.join("Hello", "world", language: "en") == "Hello world")
    #expect(SubtitleText.join("你好", "世界", language: "zh") == "你好世界")
    #expect(SubtitleText.join("", "world", language: "en") == "world")
}

@Test func separatesANewSessionsTextByScript() {
    #expect(SubtitleText.continuation(of: "than expected", with: "Good evening") == " Good evening")
    #expect(SubtitleText.continuation(of: "than expected ", with: "Good evening") == "Good evening")
    #expect(SubtitleText.continuation(of: "", with: "Good evening") == "Good evening")
    #expect(SubtitleText.continuation(of: "比预期的要小。", with: "晚上好") == "晚上好")
    #expect(SubtitleText.continuation(of: "おはよう", with: "Good") == "Good")
    #expect(SubtitleText.continuation(of: "Hello.", with: "World", unspaced: true) == "World")
}

@Test func boundsLongText() {
    let text = String(repeating: "a", count: 2001)
    #expect(SubtitleText.bounded(text).count == 1500)
    #expect(SubtitleText.bounded("short") == "short")
}

@Test func segmenterCommitsWhenTranslationEndsASentence() throws {
    var segmenter = SentenceSegmenter()
    segmenter.appendSource("Bonjour. Comment")
    #expect(segmenter.appendTranslation("Hello") == nil)
    let committed = segmenter.appendTranslation(". How")
    let sentence = try #require(committed)
    #expect(sentence.source == "Bonjour.")
    #expect(sentence.translation == "Hello.")
    segmenter.appendSource(" ça va ?")
    let committedNext = segmenter.appendTranslation(" are you?")
    let next = try #require(committedNext)
    #expect(next.source == " Comment ça va ?")
    #expect(next.translation == " How are you?")
}

@Test func transcriptTrimsAndSkipsEmptyLines() {
    let start = Date(timeIntervalSince1970: 0)
    var transcript = Transcript(startedAt: start, engine: .realtime, targetLanguage: "zh")
    transcript.append(source: " a ", translation: " A ", at: start)
    transcript.append(source: "", translation: "  ", at: start)
    transcript.append(source: "", translation: "C", at: start.addingTimeInterval(600))
    #expect(transcript.lines.map(\.translation) == ["A", "C"])
    #expect(transcript.lines.map(\.id) == [1, 2])
    #expect(transcript.summary.hasPrefix("10 min · Auto → "))
    #expect(transcript.text.hasSuffix("] a\nA\n\n[\(transcript.lines[1].time.formatted(date: .omitted, time: .standard))] C"))
    #expect(!transcript.fileName.contains(":") && !transcript.fileName.contains("/"))
}

@Test func transcriptRoundTripsThroughJSON() throws {
    var transcript = Transcript(engine: .gemini, sourceLanguage: "", targetLanguage: "ja")
    transcript.append(source: "Hello", translation: "こんにちは")
    let decoded = try JSONDecoder().decode(Transcript.self, from: JSONEncoder().encode(transcript))
    #expect(decoded == transcript)
}
