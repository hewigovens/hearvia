import Foundation
@testable import HearviaEngines
import Testing

final class ScriptedSpeech: SpeechInput, @unchecked Sendable {
    let results: AsyncThrowingStream<SpeechResult, Error>
    private let continuation: AsyncThrowingStream<SpeechResult, Error>.Continuation

    init() {
        (results, continuation) = AsyncThrowingStream.makeStream()
    }

    func say(_ text: String, final: Bool, language: String = "") {
        continuation.yield(SpeechResult(text: text, isFinal: final, language: language))
    }

    func append(_: Data) throws {}

    func finish() async {
        continuation.finish()
    }
}

/// Translates by upper-casing; `hold` keeps every request waiting until released, `failing` makes them throw.
actor ScriptedTranslator {
    struct Unavailable: LocalizedError {
        var errorDescription: String? {
            "Translator unavailable."
        }
    }

    private(set) var requests: [String] = []
    private var held: [CheckedContinuation<Void, Never>] = []
    private var holding = false
    var failing = false

    func setFailing(_ failing: Bool) {
        self.failing = failing
    }

    func hold() {
        holding = true
    }

    func release() {
        holding = false
        held.forEach { $0.resume() }
        held = []
    }

    func translate(_ text: String) async throws -> String {
        requests.append(text)
        if holding {
            await withCheckedContinuation { held.append($0) }
        }
        if failing {
            throw Unavailable()
        }
        return text.uppercased()
    }
}

@MainActor
final class Recorder {
    private(set) var updates: [EngineUpdate] = []
    private(set) var finished = false

    init(_ engine: OnDeviceEngine) {
        Task {
            for await update in engine.updates {
                updates.append(update)
            }
            finished = true
        }
    }

    var sentences: [EngineUpdate] {
        updates.filter {
            if case .sentence = $0 {
                true
            } else {
                false
            }
        }
    }
}

@MainActor
struct OnDeviceEngineTests {
    let speech = ScriptedSpeech()
    let translator = ScriptedTranslator()

    func makeEngine(source: String = "en", target: String = "fr", translates: Bool = true) -> OnDeviceEngine {
        let translator = translator
        let translate: @Sendable (String) async throws -> String = { try await translator.translate($0) }
        return OnDeviceEngine(sourceLanguage: source, targetLanguage: target) { [speech] _ in
            OnDeviceModelSet(speech: speech, translate: translates ? translate : nil, strategy: "test")
        }
    }

    @Test func translatesFinishedSegmentsInOrder() async throws {
        let engine = makeEngine()
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        speech.say("hello there.", final: true)
        speech.say("how are you?", final: true)
        try await waitUntil { recorder.updates.last == .text(source: "hello there. how are you?", translation: "HELLO THERE. HOW ARE YOU?") }
        #expect(recorder.updates.prefix(2) == [.status(.loadingModels), .status(.translating(onDevice: true))])
        #expect(recorder.sentences == [.sentence(source: "hello there.", translation: "HELLO THERE."),
                                       .sentence(source: "how are you?", translation: "HOW ARE YOU?")])
        await engine.stop()
    }

    @Test func skipsVolatileTextThatWasSuperseded() async throws {
        let engine = makeEngine()
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        await translator.hold()
        speech.say("one", final: false)
        try await waitUntil { await translator.requests == ["one"] }
        speech.say("one two", final: false)
        speech.say("one two three", final: false)
        speech.say("one two three.", final: true)
        try await waitUntil { recorder.updates.contains(.text(source: "one two three.", translation: "")) }
        await translator.release()
        try await waitUntil { !recorder.sentences.isEmpty }
        #expect(recorder.sentences == [.sentence(source: "one two three.", translation: "ONE TWO THREE.")])
        // The intermediate volatile versions were never translated.
        #expect(await translator.requests == ["one", "one two three."])
        await engine.stop()
    }

    @Test func translatesOnlyFinishedSentencesWhileDraftsAreOff() async throws {
        let engine = makeEngine()
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        engine.setTranslatesDrafts(false)
        speech.say("one two", final: false)
        speech.say("one two three.", final: true)
        try await waitUntil { !recorder.sentences.isEmpty }
        #expect(await translator.requests == ["one two three."])
        speech.say("four", final: false)
        engine.setTranslatesDrafts(true)
        try await waitUntil { await translator.requests.last == "four" }
        await engine.stop()
    }

    @Test func showsATranslationErrorUntilTranslatingWorksAgain() async throws {
        let engine = makeEngine()
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        await translator.setFailing(true)
        speech.say("first.", final: true)
        speech.say("second.", final: true)
        try await waitUntil { await translator.requests.count == 2 }
        await translator.setFailing(false)
        speech.say("third.", final: true)
        try await waitUntil { recorder.sentences.count == 3 }
        let problems = recorder.updates.filter {
            if case .problem = $0 {
                true
            } else {
                false
            }
        }
        #expect(problems == [.problem("Translator unavailable.")]) // Once, not per sentence.
        let cleared = try #require(recorder.updates.lastIndex(of: .status(.translating(onDevice: true))))
        let reported = try #require(recorder.updates.firstIndex(of: .problem("Translator unavailable.")))
        #expect(cleared > reported)
        await engine.stop()
    }

    @Test func sameLanguagePassesSpeechThrough() async throws {
        let engine = makeEngine(source: "ja", target: "ja", translates: false)
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        speech.say("こんにちは", final: false)
        speech.say("こんにちは。", final: true)
        // The text update follows the sentence; wait for it rather than the sentence alone.
        try await waitUntil { recorder.updates.last == .text(source: "こんにちは。", translation: "こんにちは。") }
        #expect(recorder.sentences == [.sentence(source: "", translation: "こんにちは。")])
        await engine.stop()
    }

    @Test func autoTranslatesFromTheDetectedLanguage() async throws {
        let translator = translator
        let translatorFrom: @Sendable (String) async throws -> Translate? = { source in
            guard source != "fr" else { return nil }
            return { text in try await translator.translate("\(source):\(text)") }
        }
        let engine = OnDeviceEngine(sourceLanguage: "", targetLanguage: "fr") { [speech] _ in
            var models = OnDeviceModelSet(speech: speech, translate: nil, strategy: "auto")
            models.translator = translatorFrom
            return models
        }
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        speech.say("hello.", final: true, language: "en")
        try await waitUntil { recorder.sentences == [.sentence(source: "hello.", translation: "EN:HELLO.")] }
        #expect(recorder.updates.contains(.log("ondevice_language_detected", ["language": "en"])))
        await engine.stop()
    }

    @Test func dropsResultsAfterStop() async throws {
        let engine = makeEngine()
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        await translator.hold()
        speech.say("late.", final: true)
        try await waitUntil { await translator.requests == ["late."] }
        await engine.stop()
        await translator.release()
        try await waitUntil { recorder.finished }
        #expect(recorder.sentences.isEmpty)
    }

    @Test func modelLoadFailureFails() async throws {
        struct Missing: LocalizedError {
            var errorDescription: String? {
                "missing model"
            }
        }
        let engine = OnDeviceEngine(sourceLanguage: "en", targetLanguage: "fr") { _ in throw Missing() }
        let recorder = Recorder(engine)
        await engine.start(audio: AsyncStream { $0.finish() })
        try await waitUntil { recorder.finished }
        #expect(recorder.updates.last == .failed("missing model"))
    }
}

@MainActor
func waitUntil(_ condition: @MainActor () async -> Bool) async throws {
    for _ in 0 ..< 400 where await !condition() {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(await condition())
}

@Test func simplifiedChineseSpeechConvertsToTraditional() async throws {
    let convert = try #require(OnDeviceModels.scriptConversion(from: "zh", to: "zh-Hant"))
    #expect(try await convert("简体中文，后来发现") == "簡體中文，後來發現")
    #expect(OnDeviceModels.scriptConversion(from: "en", to: "zh-Hant") == nil)
}
