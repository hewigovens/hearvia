#if DEBUG
    import Foundation
    import HearviaCore

    /// App Store screenshots need a believable session, and the Simulator can't capture audio: `-hearvia.demo YES` (Debug builds only) fills in one, never saved to disk.
    public extension LiveTranslator {
        static var demoRequested: Bool {
            UserDefaults.standard.bool(forKey: "hearvia.demo")
        }

        /// 12:34 on the apps' elapsed-time clock.
        static var demoListeningSince: Date {
            .now.addingTimeInterval(-demoElapsed)
        }

        private static let demoElapsed: TimeInterval = 754

        func loadDemo() {
            // 9:41, matching the status bar in Apple's screenshots.
            let now = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now) ?? .now
            let podcast = [
                ("こんにちは、「ぐっすりラジオ」へようこそ。", "Hi, and welcome to Sound Sleep Radio."),
                ("この番組では、よく眠るためのヒントを毎週お届けしています。", "Every week we share tips for sleeping better."),
                ("最近、夜中に何度も目が覚めるという声をたくさんいただきました。", "Lately, many of you have told us you keep waking up at night."),
                ("そこで、新しい研究を一つご紹介したいと思います。", "So today I'd like to introduce a new study."),
                ("今日は、毎日の小さな習慣が睡眠の質をどう変えるかについてお話しします。", "Today we're talking about how small daily habits change the quality of your sleep."),
                ("研究者たちは200人のボランティアを6か月間追跡しました。", "Researchers followed 200 volunteers for six months."),
                ("毎晩同じ時間に寝た人は、平均で20分早く眠りにつきました。", "People who went to bed at the same time every night fell asleep 20 minutes faster."),
                ("寝る1時間前に画面を消すことも役に立ちました。", "Turning off screens an hour before bed helped too.")
            ]
            transcript = Self.demoTranscript(podcast, language: "ja", startedAt: now.addingTimeInterval(-Self.demoElapsed), endedAt: now)
            source = podcast.suffix(2).map(\.0).joined()
            translation = podcast.suffix(2).map(\.1).joined(separator: " ")
            status = .translating(onDevice: true)
            isActive = true
            let day: TimeInterval = 86400
            history.transcripts = [
                Self.demoTranscript([
                    ("La revolución industrial empezó en Gran Bretaña a finales del siglo XVIII.", "The Industrial Revolution began in Britain in the late 18th century."),
                    ("El carbón y el vapor cambiaron la forma de trabajar.", "Coal and steam changed the way people worked."),
                    ("Las ciudades crecieron muy rápido.", "Cities grew very quickly.")
                ], language: "es", startedAt: now.addingTimeInterval(-day - 3600), endedAt: now.addingTimeInterval(-day - 3600 + 42 * 60)),
                Self.demoTranscript([
                    ("다음 주 화요일에 다시 이야기해요.", "Let's talk again next Tuesday."),
                    ("자료는 오늘 저녁에 보내드릴게요.", "I'll send you the materials this evening.")
                ], language: "ko", startedAt: now.addingTimeInterval(-2 * day), endedAt: now.addingTimeInterval(-2 * day + 18 * 60)),
                Self.demoTranscript([
                    ("Ajoutez deux tasses de farine et mélangez.", "Add two cups of flour and stir."),
                    ("Laissez reposer la pâte dix minutes.", "Let the dough rest for ten minutes.")
                ], language: "fr", startedAt: now.addingTimeInterval(-3 * day), endedAt: now.addingTimeInterval(-3 * day + 9 * 60)),
                Self.demoTranscript([
                    ("Il treno per Firenze parte dal binario quattro.", "The train to Florence leaves from platform four.")
                ], language: "it", startedAt: now.addingTimeInterval(-5 * day), endedAt: now.addingTimeInterval(-5 * day + 3 * 60)),
                Self.demoTranscript([
                    ("Willkommen zur Führung durch das Museum.", "Welcome to the museum tour.")
                ], language: "de", startedAt: now.addingTimeInterval(-6 * day), endedAt: now.addingTimeInterval(-6 * day + 27 * 60)),
                Self.demoTranscript([
                    ("我们下周一开始新的项目。", "We start the new project next Monday.")
                ], language: "zh", startedAt: now.addingTimeInterval(-8 * day), endedAt: now.addingTimeInterval(-8 * day + 35 * 60))
            ]
        }

        private static func demoTranscript(_ lines: [(String, String)], language: String, startedAt: Date, endedAt: Date?) -> Transcript {
            var transcript = Transcript(startedAt: startedAt, engine: .onDevice, sourceLanguage: language, targetLanguage: "en")
            for (index, line) in lines.enumerated() {
                transcript.append(source: line.0, translation: line.1, at: startedAt.addingTimeInterval(Double(index) * 9))
            }
            transcript.endedAt = endedAt
            return transcript
        }
    }
#endif
