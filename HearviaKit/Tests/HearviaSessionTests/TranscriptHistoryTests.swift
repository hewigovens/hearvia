import Foundation
import HearviaCore
@testable import HearviaSession
import Testing

@MainActor
struct TranscriptHistoryTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "hearvia-history-\(UUID().uuidString)")

    @Test func keepsTranscriptsNewestFirstAcrossLaunches() {
        let history = TranscriptHistory(directory: directory, cloudContainer: nil)
        var older = Transcript(startedAt: Date(timeIntervalSince1970: 100))
        older.append(source: "a", translation: "A")
        var newer = Transcript(startedAt: Date(timeIntervalSince1970: 200))
        newer.append(source: "b", translation: "B")
        history.save(older)
        history.save(newer)
        history.save(Transcript()) // empty: not kept

        let reloaded = TranscriptHistory(directory: directory, cloudContainer: nil)
        #expect(reloaded.transcripts.map(\.id) == [newer.id, older.id])

        reloaded.delete(newer)
        #expect(TranscriptHistory(directory: directory, cloudContainer: nil).transcripts.map(\.id) == [older.id])
    }

    @Test func aStoppedRunIsSavedWithItsSentences() async throws {
        let harness = Harness()
        let translator = harness.translator
        await translator.start()
        let engine = try #require(harness.engines.first)
        engine.send(.sentence(source: "Hello", translation: "你好"))
        await harness.settle()
        await translator.stop()
        let saved = try #require(harness.history.transcripts.first)
        #expect(saved.lines.map(\.translation) == ["你好"] && saved.endedAt != nil && saved.engine == .realtime)
    }

    @Test func nothingIsSavedWhenTurnedOff() async throws {
        let harness = Harness()
        let translator = harness.translator
        translator.savesTranscripts = false
        await translator.start()
        try #require(harness.engines.first).send(.sentence(source: "Hello", translation: "你好"))
        await harness.settle()
        await translator.stop()
        #expect(harness.history.transcripts.isEmpty)
    }
}
