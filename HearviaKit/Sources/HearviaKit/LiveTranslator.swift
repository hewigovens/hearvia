import AVFoundation
import Observation
import Security
import Translation

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
    public private(set) var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en" {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage") }
    }
    public private(set) var engine: TranslationEngine {
        didSet { UserDefaults.standard.set(engine.rawValue, forKey: "engine") }
    }
    public var apiKey: String { didSet { KeychainStore.write(apiKey) } }
    public private(set) var state = "Idle"
    public private(set) var error = ""
    public private(set) var source = ""
    public private(set) var translation = ""
    public private(set) var chunksSent = 0
    public private(set) var deltas = 0
    public private(set) var reconnects = 0
    public private(set) var lastDeltaUptime: Double?
    public private(set) var active = false
    /// Finished sentences (original + translation), oldest first, for the transcript view.
    public private(set) var transcript: [TranscriptLine] = []
    public var transcriptText: String {
        transcript.map { $0.source.isEmpty ? $0.translation : "\($0.source)\n\($0.translation)" }.joined(separator: "\n\n")
    }
    public var onTextChange: (() -> Void)?
    public var onLog: ((String, [String: String]) -> Void)?
    /// Push captured PCM here from any single serial queue.
    public nonisolated let feed = TranslationFeed()
    private var client: RealtimeTranslationClient?
    private var pump: Task<Void, Never>?
    private var generation = 0
    // On-device state. Finished segments are translated once; the volatile tail is re-translated as it changes.
    @ObservationIgnored private var pendingSource = ""
    @ObservationIgnored private var pendingTranslation = ""
    @ObservationIgnored private var speech: OnDeviceSpeech?
    @ObservationIgnored private var textTranslator: OnDeviceTextTranslator?
    @ObservationIgnored private var onDeviceTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var kick: AsyncStream<Void>.Continuation?
    @ObservationIgnored private var finalSource = ""
    @ObservationIgnored private var volatileSource = ""
    @ObservationIgnored private var finalTranslation = ""
    @ObservationIgnored private var volatileTranslation = ""
    @ObservationIgnored private var finalQueue: [String] = []
    @ObservationIgnored private var pendingVolatile: String?

    public init(fallbackKey: String = "") {
        let key = KeychainStore.read() ?? fallbackKey
        apiKey = key
        engine = UserDefaults.standard.string(forKey: "engine").flatMap(TranslationEngine.init) ?? (key.isEmpty ? .onDevice : .realtime)
    }

    public func start() async {
        guard !active else { return }
        guard engine == .onDevice || !apiKey.isEmpty else { state = "No API key"; error = "Add an OpenAI API key, or switch to on-device translation."; return }
        active = true; generation += 1
        source = ""; translation = ""; chunksSent = 0; deltas = 0; reconnects = 0; error = ""; lastDeltaUptime = nil
        transcript = []; pendingSource = ""; pendingTranslation = ""
        let chunks = feed.open()
        if engine == .onDevice { await startOnDevice(chunks, generation); return }
        pump = Task { [weak self] in
            for await chunk in chunks {
                // Audio arriving while (re)connecting is dropped; the stream stays contiguous in model time.
                guard let self, let client = self.client else { continue }
                do { try await client.append(chunk); self.chunksSent += 1 } catch { /* close event triggers reconnect */ }
            }
        }
        await connect(generation)
    }

    public func stop() async {
        guard active else { return }
        active = false; generation += 1
        feed.close(); pump?.cancel(); pump = nil
        state = "Stopped"
        stopOnDevice()
        guard let client else { return }
        self.client = nil
        await client.close()
        Task { try? await Task.sleep(for: .seconds(5)); await client.cancel() }
    }

    public func setTargetLanguage(_ language: String) async {
        targetLanguage = language
        if engine == .onDevice { await restartIfActive() } else { try? await client?.setTargetLanguage(language) }
    }

    public func setSourceLanguage(_ language: String) async {
        sourceLanguage = language
        if engine == .onDevice { await restartIfActive() }
    }

    public func setEngine(_ engine: TranslationEngine) async {
        guard engine != self.engine else { return }
        self.engine = engine
        await restartIfActive()
    }

    private func restartIfActive() async {
        guard active else { return }
        await stop(); await start()
    }

    // MARK: On-device

    private func startOnDevice(_ chunks: AsyncStream<Data>, _ attempt: Int) async {
        finalSource = ""; volatileSource = ""; finalTranslation = ""; volatileTranslation = ""; finalQueue = []; pendingVolatile = nil
        state = "Loading on-device models"
        let (from, to) = (sourceLanguage, targetLanguage)
        do {
            let translator = from == to ? nil : try await OnDeviceTextTranslator(source: from, target: to)
            let speech = try await OnDeviceSpeech(language: from) { [weak self] p in
                Task { @MainActor in if self?.generation == attempt { self?.state = "Downloading speech model \(Int(p * 100))%" } }
            }
            guard active, attempt == generation else { await speech.finish(); return }
            self.speech = speech; textTranslator = translator
            let (kicks, kick) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.kick = kick
            state = "Translating on device"
            onLog?("ondevice_started", ["source": from, "target": to, "translation_model": translator?.strategy ?? "none"])
            pump = Task { [weak self] in
                for await chunk in chunks {
                    do { try speech.append(chunk); self?.chunksSent += 1 } catch { self?.onLog?("ondevice_audio_error", ["error": "\(error)"]) }
                }
            }
            onDeviceTasks = [
                Task { [weak self] in
                    do {
                        for try await t in speech.results { self?.handleTranscript(t, attempt) }
                    } catch { self?.failOnDevice(error, attempt) }
                },
                Task { [weak self] in
                    for await _ in kicks { await self?.drainTranslations(attempt) }
                },
            ]
        } catch { failOnDevice(error, attempt) }
    }

    private func stopOnDevice() {
        kick?.finish(); kick = nil
        onDeviceTasks.forEach { $0.cancel() }; onDeviceTasks = []
        textTranslator = nil
        if let speech { self.speech = nil; Task { await speech.finish() } }
    }

    private func failOnDevice(_ failure: Error, _ attempt: Int) {
        guard attempt == generation else { return }
        error = failure.localizedDescription; state = "Failed"
        onLog?("ondevice_error", ["error": "\(failure)"])
        active = false; generation += 1
        feed.close(); pump?.cancel(); pump = nil
        stopOnDevice()
    }

    private func handleTranscript(_ t: Transcript, _ attempt: Int) {
        guard attempt == generation else { return }
        let text = t.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isFinal {
            volatileSource = ""; pendingVolatile = nil
            if !text.isEmpty { finalSource = Self.trim(Self.join(finalSource, text, sourceLanguage)); finalQueue.append(text) }
        } else {
            volatileSource = text; pendingVolatile = text
        }
        source = Self.join(finalSource, volatileSource, sourceLanguage)
        if textTranslator == nil { // Same language: subtitles are the transcript.
            translation = source; finalQueue = []; pendingVolatile = nil
            if t.isFinal { appendTranscript(source: "", translation: text) }
            deltas += 1; lastDeltaUptime = ProcessInfo.processInfo.systemUptime
        }
        onTextChange?()
        kick?.yield()
    }

    /// One request at a time: finished segments first, then the newest volatile text (older ones are skipped).
    private func drainTranslations(_ attempt: Int) async {
        while attempt == generation, let translator = textTranslator {
            if !finalQueue.isEmpty {
                let text = finalQueue.removeFirst()
                let output = await translate(text, translator, attempt)
                guard attempt == generation else { return }
                finalTranslation = Self.trim(Self.join(finalTranslation, output, targetLanguage))
                volatileTranslation = ""
                appendTranscript(source: text, translation: output)
            } else if let text = pendingVolatile {
                pendingVolatile = nil
                let output = await translate(text, translator, attempt)
                guard attempt == generation else { return }
                if finalQueue.isEmpty && !volatileSource.isEmpty { volatileTranslation = output } // else superseded
            } else { return }
            translation = Self.join(finalTranslation, volatileTranslation, targetLanguage)
            deltas += 1; lastDeltaUptime = ProcessInfo.processInfo.systemUptime
            onTextChange?()
        }
    }

    private func translate(_ text: String, _ translator: OnDeviceTextTranslator, _ attempt: Int) async -> String {
        do { return try await translator.translate(text) } catch TranslationError.notInstalled {
            failOnDevice(OnDeviceError.translationNotInstalled(sourceLanguage, targetLanguage), attempt) // Removed mid-session.
        } catch TranslationError.nothingToTranslate {
        } catch {
            if attempt == generation { onLog?("ondevice_translate_error", ["error": "\(error)", "text": text]) }
        }
        return ""
    }

    private func appendTranscript(source: String, translation: String) {
        let line = TranscriptLine(id: (transcript.last?.id ?? 0) + 1, source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                                  translation: translation.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !line.translation.isEmpty || !line.source.isEmpty else { return }
        transcript.append(line)
        if transcript.count > 300 { transcript.removeFirst(transcript.count - 300) }
    }

    /// Realtime deltas are a continuous stream; cut a transcript line whenever the translation ends a sentence.
    /// The source is cut at its own last sentence end, so the pairing is approximate.
    private func commitRealtimeSentences() {
        guard let end = pendingTranslation.lastIndex(where: Self.sentenceEnds.contains) else { return }
        let translated = String(pendingTranslation[...end])
        pendingTranslation = String(pendingTranslation[pendingTranslation.index(after: end)...])
        var spoken = pendingSource
        if let sourceEnd = pendingSource.lastIndex(where: Self.sentenceEnds.contains) {
            spoken = String(pendingSource[...sourceEnd]); pendingSource = String(pendingSource[pendingSource.index(after: sourceEnd)...])
        } else { pendingSource = "" }
        appendTranscript(source: spoken, translation: translated)
    }

    private static let sentenceEnds: Set<Character> = [".", "!", "?", "。", "！", "？", "…"]

    private static func join(_ a: String, _ b: String, _ language: String) -> String {
        if a.isEmpty || b.isEmpty { return a + b }
        return ["zh", "ja"].contains(language) ? a + b : a + " " + b
    }

    private func connect(_ attempt: Int) async {
        guard active, attempt == generation else { return }
        state = reconnects == 0 ? "Connecting" : "Reconnecting (\(reconnects))"
        let client = RealtimeTranslationClient(configuration: .init(targetLanguage: targetLanguage), credential: apiKey)
        self.client = client
        Task { [weak self] in
            for await event in client.events { self?.handle(event, from: client) }
        }
        do {
            try await client.connect()
            onLog?("translation_connected", ["target": targetLanguage, "reconnects": "\(reconnects)"])
        } catch {
            handle(.closed(reason: error.localizedDescription), from: client)
        }
    }

    private func handle(_ event: TranslationEvent, from sender: RealtimeTranslationClient) {
        guard sender === client else { return }
        switch event {
        case .sessionCreated(let id, let expires):
            state = "Translating"; error = ""
            onLog?("translation_session", ["id": id, "expires": expires.map { "\($0)" } ?? ""])
        case .sessionUpdated, .audioDelta: break
        case .sourceDelta(let d, _): source = Self.trim(source + d); pendingSource += d; onTextChange?()
        case .translationDelta(let d, _):
            translation = Self.trim(translation + d); deltas += 1
            pendingTranslation += d; commitRealtimeSentences()
            lastDeltaUptime = ProcessInfo.processInfo.systemUptime
            onTextChange?()
        case .serverError(let type, let code, let message):
            error = "\(code ?? type): \(message)"
            onLog?("translation_error", ["type": type, "code": code ?? "", "message": message])
        case .closed(let reason):
            onLog?("translation_closed", ["reason": reason ?? "session.closed", "chunks": "\(chunksSent)", "deltas": "\(deltas)"])
            client = nil
            guard active else { return }
            // Fatal auth/config errors would loop forever; stop instead.
            if error.contains("invalid_api_key") || error.contains("insufficient_quota") || reconnects >= 20 {
                active = false; feed.close(); pump?.cancel(); state = "Failed"; return
            }
            reconnects += 1
            let attempt = generation
            let delay = min(10.0, 0.5 * Double(1 << min(reconnects, 5)))
            state = "Reconnecting in \(Int(delay.rounded(.up))) s"
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                await self?.connect(attempt)
            }
        }
    }

    /// Bounded history; displays show only the tail that fits.
    private static func trim(_ text: String) -> String { text.count > 2_000 ? String(text.suffix(1_500)) : text }
}

public struct TranscriptLine: Identifiable, Sendable, Equatable {
    public let id: Int
    public let source: String
    public let translation: String
}

/// Thread-safe PCM sink. Ordering is preserved by the single AsyncStream consumer.
public final class TranslationFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var resampler = PCM16Resampler()
    private var continuation: AsyncStream<Data>.Continuation?

    public init() {}

    func open() -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(150)) // 30 s backlog cap
        lock.withLock { self.continuation?.finish(); self.continuation = continuation; resampler = PCM16Resampler() }
        return stream
    }

    func close() { lock.withLock { continuation?.finish(); continuation = nil } }

    public func push(_ pcm: AVAudioPCMBuffer) {
        lock.withLock {
            guard let continuation else { return }
            for chunk in (try? resampler.append(pcm)) ?? [] { continuation.yield(chunk) }
        }
    }
}

public enum KeychainStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.hewig.Hearvia",
         kSecAttrAccount as String: "openai-api-key"]
    }

    public static func read() -> String? {
        var item: CFTypeRef?
        var q = query; q[kSecReturnData as String] = true
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func write(_ value: String) {
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var q = query
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
