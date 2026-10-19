import Speech

extension OnDeviceSpeech {
    private enum Event: Sendable {
        case result(Int, SpeechTranscriber.Result)
        case ended(Int, (any Error)?)
        case tick
    }

    /// Auto: withholds results until `LanguageContest` picks a recognizer, then forwards only the winner's, from the beginning. Undecided runs are finished every 3 s so there's something to score; a sentence the winner is unsure of reopens the contest.
    static func detect(languages: [String], names: [ObjectIdentifier: String], analyzer: SpeechAnalyzer,
                       output: AsyncThrowingStream<SpeechResult, Error>.Continuation) async {
        let (events, sink) = AsyncStream<Event>.makeStream()
        var contest = LanguageContest(languages: languages)
        await withTaskGroup { group in
            func listen(_ module: SpeechTranscriber, _ language: String) {
                let id = contest.add(module, language)
                group.addTask {
                    do {
                        for try await result in module.results {
                            sink.yield(.result(id, result))
                        }
                        sink.yield(.ended(id, nil))
                    } catch { sink.yield(.ended(id, error)) }
                }
            }
            for module in await analyzer.modules.compactMap({ $0 as? SpeechTranscriber }) {
                listen(module, names[ObjectIdentifier(module)] ?? "")
            }
            group.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    sink.yield(.tick)
                }
            }
            for await event in events {
                switch event {
                case let .result(id, result):
                    for (module, language) in await handle(result, from: id, in: &contest, analyzer: analyzer, output: output) {
                        listen(module, language)
                    }
                case .tick:
                    if contest.winner == nil {
                        try? await analyzer.finalize(through: nil)
                        await apply(contest.tick(), in: &contest, analyzer: analyzer, output: output)
                    }
                case let .ended(id, error):
                    guard contest.candidates[id] != nil else { continue } // Removed by setModules.
                    if contest.winner == id || contest.candidates.count == 1 {
                        if let error {
                            output.finish(throwing: error)
                        } else {
                            output.finish()
                        }
                        group.cancelAll()
                        return
                    }
                    await apply(contest.remove(id), in: &contest, analyzer: analyzer, output: output)
                }
            }
        }
    }
}

private extension OnDeviceSpeech {
    /// Returns new recognizers to listen to when the contest reopens.
    static func handle(_ result: SpeechTranscriber.Result, from id: Int, in contest: inout LanguageContest,
                       analyzer: SpeechAnalyzer, output: AsyncThrowingStream<SpeechResult, Error>.Continuation) async -> [(SpeechTranscriber, String)] {
        guard let entry = contest.candidates[id] else { return [] }
        if contest.winner == nil {
            if result.isFinal {
                await apply(contest.heard(result, from: id), in: &contest, analyzer: analyzer, output: output)
            }
            return []
        }
        guard result.isFinal, LanguageContest.isUnsure(result) else {
            output.yield(SpeechResult(result, language: entry.language))
            return []
        }
        contest.reopen(after: result)
        var added: [(SpeechTranscriber, String)] = []
        for language in contest.languages where language != entry.language {
            if let module = try? await OnDeviceModels.transcriber(language, confidence: true) {
                added.append((module, language))
            }
        }
        try? await analyzer.setModules([entry.module] + added.map(\.0))
        return added
    }

    static func apply(_ decision: LanguageContest.Decision?, in contest: inout LanguageContest, analyzer: SpeechAnalyzer,
                      output: AsyncThrowingStream<SpeechResult, Error>.Continuation) async {
        guard let decision else { return }
        let (winner, finals, note) = contest.decide(decision)
        try? await analyzer.setModules([winner.module])
        for (index, result) in finals.enumerated() {
            var forwarded = SpeechResult(result, language: winner.language)
            forwarded.detection = index == 0 ? note : ""
            output.yield(forwarded)
        }
    }
}
