import Foundation
@testable import HearviaCore
import Testing

@Test func blankQueryMatchesEverySessionAndMarksNothing() {
    let transcript = sample([("Hello", "你好")])
    #expect(transcript.matches("") && transcript.matches("   "))
    #expect(!transcript.lines[0].matches("") && !transcript.lines[0].matches(" \n"))
    #expect(TranscriptSearch.matchRanges(in: "sleeping", query: "  ").isEmpty)
}

@Test func searchHitsOriginalOrTranslationAndIgnoresCase() {
    let french = sample([("Ajoutez deux tasses de farine.", "Add two cups of flour and stir.")])
    let italian = sample([("Il treno per Firenze parte.", "The train to Florence leaves.")])
    let korean = sample([("다음 주 화요일에 다시 이야기해요.", "Let's talk again next Tuesday.")])
    #expect(french.matches("flour") && french.matches("  Flour "))
    #expect(!french.matches("Firenze"))
    #expect(italian.matches("firenze") && !italian.matches("flour"))
    #expect(korean.matches("Tuesday"))
    #expect(korean.lines[0].matches("화요일"))
    #expect(!korean.lines[0].matches("flour"))
}

@Test func substringMatchCanSitInsideAWord() {
    let sleeping = sample([
        ("こんにちは。", "Hi, and welcome to Sound Sleep Radio."),
        ("よく眠る。", "Every week we share tips for sleeping better."),
        ("同じ時間。", "People who went to bed at the same time fell asleep faster.")
    ])
    #expect(sleeping.matches("sleep"))
    #expect(sleeping.lines[0].matches("sleep"))
    #expect(sleeping.lines[1].matches("sleep"))
    #expect(sleeping.lines[2].matches("sleep"))
    #expect(sleeping.lines.first { $0.matches("sleep") }?.translation == "Hi, and welcome to Sound Sleep Radio.")
    #expect(!sleeping.matches("zzz"))
}

@Test func rangesStayInsideTheOriginalCasingAndDoNotOverlap() {
    let locale = Locale(identifier: "en_US")
    let sleep = TranscriptSearch.matchRanges(in: "Sound Sleep Radio", query: "sleep", locale: locale)
    #expect(sleep.count == 1)
    #expect(String("Sound Sleep Radio"[sleep[0]]) == "Sleep")

    let inside = TranscriptSearch.matchRanges(in: "sleeping and asleep", query: "sleep", locale: locale)
    #expect(inside.map { String("sleeping and asleep"[$0]) } == ["sleep", "sleep"])

    let crowded = TranscriptSearch.matchRanges(in: "aaa", query: "aa", locale: locale)
    #expect(crowded.count == 1)
    #expect(String("aaa"[crowded[0]]) == "aa")
}

@Test func diacriticsDoNotHideAMatch() {
    let locale = Locale(identifier: "en_US")
    let ranges = TranscriptSearch.matchRanges(in: "café", query: "cafe", locale: locale)
    #expect(ranges.count == 1)
    #expect(String("café"[ranges[0]]) == "café")
    var transcript = Transcript()
    transcript.append(source: "café", translation: "coffee")
    #expect(transcript.matches("cafe"))
}

@Test func selectionMovesToASessionThatStartsMatching() {
    var live = sample([("Hello", "你好")])
    let before = TranscriptMatches(query: "flour", live: live, saved: [])
    #expect(before.nothingMatches && before.selection(keeping: nil) == nil)
    live.append(source: "Ajoutez deux tasses de farine.", translation: "Add two cups of flour.")
    let after = TranscriptMatches(query: "flour", live: live, saved: [])
    #expect(!after.nothingMatches && after.selection(keeping: nil) == live.id)
}

@Test func selectionStaysOnAListedRowAndOtherwiseTakesTheFirst() {
    let live = sample([("Il treno per Firenze parte.", "The train to Florence leaves.")])
    let flour = sample([("Ajoutez deux tasses de farine.", "Add two cups of flour.")])
    let bread = sample([("Le pain est chaud.", "The bread, made with flour, is warm.")])
    let search = TranscriptMatches(query: "flour", live: live, saved: [flour, bread])
    #expect(search.ids == [flour.id, bread.id])
    #expect(search.selection(keeping: bread.id) == bread.id)
    #expect(search.selection(keeping: live.id) == flour.id)
    let everything = TranscriptMatches(query: " ", live: live, saved: [flour, bread])
    #expect(!everything.isSearching && everything.ids == [live.id, flour.id, bread.id])
    #expect(everything.selection(keeping: UUID()) == live.id)
}

private func sample(_ lines: [(String, String)]) -> Transcript {
    var transcript = Transcript()
    for line in lines {
        transcript.append(source: line.0, translation: line.1)
    }
    return transcript
}
