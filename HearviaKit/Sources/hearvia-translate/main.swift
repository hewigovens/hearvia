import AVFoundation
import Foundation
import HearviaKit

// Streams an audio file to gpt-realtime-translate at real-time pace and prints
// source/translated text with lag measurements.
// Usage: hearvia-translate <audio-file> [target-lang=zh] [--fast]

func apiKey() -> String? {
    if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
        return key
    }
    var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    for _ in 0 ..< 4 {
        if let text = try? String(contentsOf: dir.appending(path: ".env"), encoding: .utf8) {
            for line in text.split(separator: "\n") where line.hasPrefix("OPENAI_API_KEY=") {
                return String(line.dropFirst("OPENAI_API_KEY=".count)).trimmingCharacters(in: .init(charactersIn: "\"' "))
            }
        }
        dir.deleteLastPathComponent()
    }
    return nil
}

let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
guard let path = args.first else { print("usage: hearvia-translate <audio-file> [lang] [--fast] [--on-device=<spoken-lang>]")
    exit(2)
}
let language = args.dropFirst().first ?? "zh"
let realtime = !CommandLine.arguments.contains("--fast")

if let flag = CommandLine.arguments.first(where: { $0.hasPrefix("--on-device") }) {
    let spoken = flag.split(separator: "=").dropFirst().first.map(String.init) ?? "en"
    try await runOnDevice(path: path, spoken: spoken, target: language)
    exit(0)
}
guard let key = apiKey() else { print("OPENAI_API_KEY not set and no .env found")
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

let client = RealtimeTranslationClient(configuration: .init(targetLanguage: language), credential: key)
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
        case let .sessionCreated(id, expires): print("[\(stamp())] session.created \(id) expires=\(expires.map { "\($0)" } ?? "-")")
        case .sessionUpdated: print("[\(stamp())] session.updated")
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
        case let .serverError(type, code, message): print("[\(stamp())] ERROR \(type) \(code ?? "") \(message)")
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

/// Feeds the file through LiveTranslator's on-device engine at real-time pace, printing each text change.
@MainActor func runOnDevice(path: String, spoken: String, target: String) async throws {
    let translator = LiveTranslator()
    await translator.setEngine(.onDevice)
    await translator.setSourceLanguage(spoken)
    await translator.setTargetLanguage(target)
    let start = Date()
    func stamp() -> String {
        String(format: "%6.2fs", Date().timeIntervalSince(start))
    }
    var last = ""
    translator.onTextChange = {
        guard translator.translation != last else { return }
        last = translator.translation
        print("[\(stamp())] SRC \(translator.source.suffix(70).debugDescription)\n          TR  \(translator.translation.suffix(70).debugDescription)")
    }
    translator.onLog = { name, fields in print("[\(stamp())] \(name) \(fields)") }
    await translator.start()
    print("[\(stamp())] \(translator.state) \(translator.error)")
    guard translator.active else { return }
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let block: AVAudioFrameCount = 4800
    let streamStart = Date()
    var sent = 0.0
    func feed(_ buffer: AVAudioPCMBuffer) async throws {
        translator.feed.push(buffer)
        sent += Double(buffer.frameLength) / buffer.format.sampleRate
        let wait = streamStart.addingTimeInterval(sent).timeIntervalSinceNow
        if wait > 0 {
            try await Task.sleep(for: .seconds(wait))
        }
    }
    while file.framePosition < file.length {
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
        try file.read(into: buffer, frameCount: block)
        try await feed(buffer)
    }
    print("[\(stamp())] audio ended (\(String(format: "%.1f", sent)) s)")
    for _ in 0 ..< 15 { // 3 s of silence so the last segment finalizes
        let silence = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: block)!
        silence.frameLength = block
        try await feed(silence)
    }
    try await Task.sleep(for: .seconds(2))
    print("\n--- source ---\n\(translator.source)\n--- translation ---\n\(translator.translation)\nerror: \(translator.error)")
    await translator.stop()
}
