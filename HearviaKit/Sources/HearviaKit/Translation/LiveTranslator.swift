import Foundation
import Observation

/// Platform-neutral live subtitle pipeline: captured PCM → `feed` → engine → text.
/// Realtime: gpt-realtime-translate, translated audio discarded, reconnects with backoff while active.
/// On-device: SpeechTranscriber → Translation framework, translated per segment (volatile text is re-translated).
@MainActor @Observable
public final class LiveTranslator {
    public static let languages = ["zh", "en", "ja", "ko", "es", "fr", "de", "pt", "it", "ru", "hi", "id", "vi"]

    public var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "zh" {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    /// Spoken language; only the on-device engine needs it (realtime auto-detects).
    public internal(set) var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en" {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage") }
    }
    public internal(set) var engine: TranslationEngine {
        didSet { UserDefaults.standard.set(engine.rawValue, forKey: "engine") }
    }
    public var apiKey: String {
        didSet { KeychainStore.write(apiKey) }
    }
    public internal(set) var state = "Idle"
    public internal(set) var error = ""
    public internal(set) var source = ""
    public internal(set) var translation = ""
    public internal(set) var chunksSent = 0
    public internal(set) var deltas = 0
    public internal(set) var reconnects = 0
    public internal(set) var lastDeltaUptime: Double?
    public internal(set) var active = false
    /// Finished sentences (original + translation), oldest first, for the transcript view.
    public internal(set) var transcript: [TranscriptLine] = []
    public var onTextChange: (() -> Void)?
    public var onLog: ((String, [String: String]) -> Void)?
    /// Push captured PCM here from any single serial queue.
    public nonisolated let feed = TranslationFeed()
    @ObservationIgnored var client: RealtimeTranslationClient?
    @ObservationIgnored var pump: Task<Void, Never>?
    @ObservationIgnored var generation = 0
    @ObservationIgnored var pendingSource = ""
    @ObservationIgnored var pendingTranslation = ""
    @ObservationIgnored var speech: OnDeviceSpeech?
    @ObservationIgnored var textTranslator: OnDeviceTextTranslator?
    @ObservationIgnored var onDeviceTasks: [Task<Void, Never>] = []
    @ObservationIgnored var kick: AsyncStream<Void>.Continuation?
    @ObservationIgnored var finalSource = ""
    @ObservationIgnored var volatileSource = ""
    @ObservationIgnored var finalTranslation = ""
    @ObservationIgnored var volatileTranslation = ""
    @ObservationIgnored var finalQueue: [String] = []
    @ObservationIgnored var pendingVolatile: String?

    public init(fallbackKey: String = "") {
        let key = KeychainStore.read() ?? fallbackKey
        apiKey = key
        engine = UserDefaults.standard.string(forKey: "engine").flatMap(TranslationEngine.init) ?? (key.isEmpty ? .onDevice : .realtime)
    }

    public func start() async {
        guard !active else { return }
        guard engine == .onDevice || !apiKey.isEmpty else { state = "No API key"
            error = "Add an OpenAI API key, or switch to on-device translation."
            return
        }
        active = true
        generation += 1
        source = ""
        translation = ""
        chunksSent = 0
        deltas = 0
        reconnects = 0
        error = ""
        lastDeltaUptime = nil
        transcript = []
        pendingSource = ""
        pendingTranslation = ""
        let chunks = feed.open()
        if engine == .onDevice {
            await startOnDevice(chunks, generation)
            return
        }
        pump = Task { [weak self] in
            for await chunk in chunks {
                // Audio arriving while (re)connecting is dropped; the stream stays contiguous in model time.
                guard let self, let client = self.client else { continue }
                do { try await client.append(chunk)
                    self.chunksSent += 1
                } catch { /* close event triggers reconnect */ }
            }
        }
        await connect(generation)
    }

    public func stop() async {
        guard active else { return }
        active = false
        generation += 1
        feed.close()
        pump?.cancel()
        pump = nil
        state = "Stopped"
        stopOnDevice()
        guard let client else { return }
        self.client = nil
        await client.close()
        Task { try? await Task.sleep(for: .seconds(5))
            await client.cancel()
        }
    }

    public func setTargetLanguage(_ language: String) async {
        targetLanguage = language
        if engine == .onDevice {
            await restartIfActive()
        } else {
            try? await client?.setTargetLanguage(language)
        }
    }

    public func setSourceLanguage(_ language: String) async {
        sourceLanguage = language
        if engine == .onDevice {
            await restartIfActive()
        }
    }

    public func setEngine(_ engine: TranslationEngine) async {
        guard engine != self.engine else { return }
        self.engine = engine
        await restartIfActive()
    }

    func restartIfActive() async {
        guard active else { return }
        await stop()
        await start()
    }

    static func join(_ a: String, _ b: String, _ language: String) -> String {
        if a.isEmpty || b.isEmpty {
            return a + b
        }
        return ["zh", "ja"].contains(language) ? a + b : a + " " + b
    }

    /// Bounded history; displays show only the tail that fits.
    static func trim(_ text: String) -> String {
        text.count > 2000 ? String(text.suffix(1500)) : text
    }
}
