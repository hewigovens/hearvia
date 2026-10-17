import AVFoundation
import Foundation
import HearviaAudio
import HearviaEngines

// Streams an audio file through an engine at real-time pace and prints the text as it arrives.
// Usage: hearvia-translate <audio-file> [target-lang=zh] [--fast] [--gemini | --on-device=<spoken-lang or auto>]
// OpenAI Realtime by default (it also reports lag); --fast sends the audio as quickly as possible.

/// `name` from the environment, else from the nearest `.env` up to four directories above.
func secret(_ name: String) -> String? {
    if let key = ProcessInfo.processInfo.environment[name], !key.isEmpty {
        return key
    }
    var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    for _ in 0 ..< 4 {
        if let text = try? String(contentsOf: dir.appending(path: ".env"), encoding: .utf8) {
            for line in text.split(separator: "\n") where line.hasPrefix("\(name)=") {
                return String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .init(charactersIn: "\"' "))
            }
        }
        dir.deleteLastPathComponent()
    }
    return nil
}

let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
guard let path = args.first else { print("usage: hearvia-translate <audio-file> [lang] [--fast] [--gemini | --on-device=<spoken-lang or auto>]")
    exit(2)
}
let language = args.dropFirst().first ?? "zh"
let realtime = !CommandLine.arguments.contains("--fast")

if let flag = CommandLine.arguments.first(where: { $0.hasPrefix("--on-device") }) {
    let spoken = flag.split(separator: "=").dropFirst().first.map(String.init).map { $0 == "auto" ? "" : $0 } ?? "en"
    try await runOnDevice(path: path, spoken: spoken, target: language)
    exit(0)
}
let gemini = CommandLine.arguments.contains("--gemini")
let keyName = gemini ? "GEMINI_API_KEY" : "OPENAI_API_KEY"
guard let key = secret(keyName) else { print("\(keyName) not set and no .env found")
    exit(2)
}

let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
let resampler = PCM16Resampler()
var chunks: [Data] = []
let block: AVAudioFrameCount = 4096
while file.framePosition < file.length {
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
    try file.read(into: buffer, frameCount: block)
    chunks += try resampler.append(buffer)
}
chunks += Array(repeating: PCM16Resampler.silenceChunk, count: 15) // 3 s tail so the model can finish
print("audio: \(file.fileFormat.sampleRate) Hz × \(file.fileFormat.channelCount) ch → \(chunks.count) chunks of 200 ms, target=\(language)")

let client: any TranslationSocket = gemini
    ? GeminiLiveClient(configuration: GeminiLiveConfiguration(targetLanguage: language), apiKey: key)
    : OpenAIRealtimeClient(configuration: OpenAIRealtimeConfiguration(targetLanguage: language), credential: key)
let start = Date()
nonisolated(unsafe) var streamStart = Date.distantFuture
func stamp() -> String {
    String(format: "%6.2fs", Date().timeIntervalSince(start))
}

let receiver = Task {
    var source = "", translation = "", audioBytes = 0
    var firstSource: TimeInterval?, firstTranslation: TimeInterval?
    var lags: [Double] = []
    for await event in client.events {
        let now = Date().timeIntervalSince(start)
        switch event {
        case let .sessionStarted(id, expires): print("[\(stamp())] session started \(id) expires=\(expires.map { "\($0)" } ?? "-")")
        case let .expiring(at): print("[\(stamp())] expiring in \(Int(at.timeIntervalSinceNow)) s")
        case let .sourceDelta(d, _):
            if firstSource == nil {
                firstSource = now
            }
            source += d
            print("[\(stamp())] SRC  \(d.debugDescription)")
        case let .translationDelta(d, ms):
            if firstTranslation == nil {
                firstTranslation = now
            }
            if let ms, realtime {
                lags.append(Date().timeIntervalSince(streamStart) - Double(ms) / 1000)
            }
            translation += d
            print("[\(stamp())] TR   \(d.debugDescription) elapsed_ms=\(ms.map(String.init) ?? "-")")
        case let .audioDelta(bytes, _): audioBytes += bytes
        case let .serverError(code, message, fatal): print("[\(stamp())] ERROR \(code) \(message)\(fatal ? " (fatal)" : "")")
        case let .closed(reason): print("[\(stamp())] closed \(reason ?? "session.closed")")
        }
    }
    print("\n--- source ---\n\(source)\n--- translation ---\n\(translation)")
    print(String(format: "first source text: %@  first translation: %@",
                 firstSource.map { String(format: "%.2fs", $0) } ?? "-", firstTranslation.map { String(format: "%.2fs", $0) } ?? "-"))
    if !lags.isEmpty {
        let sorted = lags.sorted()
        print(String(format: "delivery delay vs elapsed_ms: median %.2fs, max %.2fs", sorted[sorted.count / 2], sorted.last!))
    }
}

do {
    try await client.connect()
    streamStart = Date()
    for (i, chunk) in chunks.enumerated() {
        try await client.append(chunk)
        if realtime {
            let due = streamStart.addingTimeInterval(Double(i + 1) * 0.2)
            let wait = due.timeIntervalSinceNow
            if wait > 0 {
                try await Task.sleep(for: .seconds(wait))
            }
        }
    }
} catch {
    print("[\(stamp())] send failed: \(error.localizedDescription)")
}
print("[\(stamp())] sent all audio, closing")
await client.close()
let timeout = Task { try await Task.sleep(for: .seconds(20))
    await client.cancel()
}
await receiver.value
timeout.cancel()

@MainActor func runOnDevice(path: String, spoken: String, target: String) async throws {
    let engine = OnDeviceEngine(sourceLanguage: spoken, targetLanguage: target)
    let feed = AudioFeed()
    let start = Date()
    func stamp() -> String {
        String(format: "%6.2fs", Date().timeIntervalSince(start))
    }
    var source = "", translation = "", failure = ""
    var ready: CheckedContinuation<Bool, Never>?
    let printer = Task {
        for await update in engine.updates {
            switch update {
            case let .status(status):
                print("[\(stamp())] \(status.label)")
                if case .translating = status {
                    ready?.resume(returning: true)
                    ready = nil
                }
            case let .text(newSource, newTranslation):
                source = newSource
                guard newTranslation != translation else { continue }
                translation = newTranslation
                print("[\(stamp())] SRC \(source.suffix(70).debugDescription)\n          TR  \(translation.suffix(70).debugDescription)")
            case let .failed(message):
                failure = message
                print("[\(stamp())] failed: \(message)")
                ready?.resume(returning: false)
                ready = nil
            case let .log(name, fields): print("[\(stamp())] \(name) \(fields)")
            case .sentence, .audioConsumed, .problem: break
            }
        }
    }
    let started = await withCheckedContinuation { continuation in
        ready = continuation
        Task { await engine.start(audio: feed.open()) }
    }
    guard started else { return }
    let sent = try await stream(path, into: feed)
    print("[\(stamp())] audio ended (\(String(format: "%.1f", sent)) s)")
    try await Task.sleep(for: .seconds(2))
    feed.close()
    await engine.stop()
    await printer.value
    print("\n--- source ---\n\(source)\n--- translation ---\n\(translation)\nerror: \(failure)")
}

/// Pushes the file and 3 s of silence (so the last segment finalizes) into `feed` at real-time pace; returns the seconds sent.
func stream(_ path: String, into feed: AudioFeed) async throws -> Double {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let block: AVAudioFrameCount = 4800
    let streamStart = Date()
    var sent = 0.0
    func push(_ buffer: AVAudioPCMBuffer) async throws {
        feed.push(buffer)
        sent += Double(buffer.frameLength) / buffer.format.sampleRate
        let wait = streamStart.addingTimeInterval(sent).timeIntervalSinceNow
        if wait > 0 {
            try await Task.sleep(for: .seconds(wait))
        }
    }
    while file.framePosition < file.length {
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
        try file.read(into: buffer, frameCount: block)
        try await push(buffer)
    }
    for _ in 0 ..< 15 {
        let silence = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
        silence.frameLength = block
        try await push(silence)
    }
    return sent
}
