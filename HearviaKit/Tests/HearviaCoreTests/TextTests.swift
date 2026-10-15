@testable import HearviaCore
import Testing

@Test func joinsWithSpacesExceptInUnspacedLanguages() {
    #expect(SubtitleText.join("Hello", "world", language: "en") == "Hello world")
    #expect(SubtitleText.join("你好", "世界", language: "zh") == "你好世界")
    #expect(SubtitleText.join("", "world", language: "en") == "world")
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

@Test func transcriptTrimsSkipsEmptyAndCaps() {
    var transcript = Transcript(limit: 2)
    transcript.append(source: " a ", translation: " A ")
    transcript.append(source: "", translation: "  ")
    transcript.append(source: "b", translation: "B")
    transcript.append(source: "", translation: "C")
    #expect(transcript.lines.map(\.translation) == ["B", "C"])
    #expect(transcript.lines.map(\.id) == [2, 3])
    #expect(transcript.text == "b\nB\n\nC")
}
