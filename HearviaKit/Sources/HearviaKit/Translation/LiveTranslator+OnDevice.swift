import Foundation
import Translation

/// On-device engine: finished segments are translated once; the volatile tail is re-translated as it changes.
extension LiveTranslator {
    func startOnDevice(_ chunks: AsyncStream<Data>, _ attempt: Int) async {
        finalSource = ""
        volatileSource = ""
        finalTranslation = ""
        volatileTranslation = ""
        finalQueue = []
        pendingVolatile = nil
        state = "Loading on-device models"
        let (from, to) = (sourceLanguage, targetLanguage)
        do {
            let translator = from == to ? nil : try await OnDeviceTextTranslator(source: from, target: to)
            let speech = try await OnDeviceSpeech(language: from) { [weak self] p in
                Task {
                    @MainActor in if self?.generation == attempt {
                        self?.state = "Downloading speech model \(Int(p * 100))%"
                    }
                }
            }
            guard active, attempt == generation else { await speech.finish()
                return
            }
            self.speech = speech
            textTranslator = translator
            let (kicks, kick) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            self.kick = kick
            state = "Translating on device"
            onLog?("ondevice_started", ["source": from, "target": to, "translation_model": translator?.strategy ?? "none"])
            pump = Task { [weak self] in
                for await chunk in chunks {
                    do { try speech.append(chunk)
                        self?.chunksSent += 1
                    } catch { self?.onLog?("ondevice_audio_error", ["error": "\(error)"]) }
                }
            }
            onDeviceTasks = [
                Task { [weak self] in
                    do {
                        for try await t in speech.results {
                            self?.handleSpeech(t, attempt)
                        }
                    } catch { self?.failOnDevice(error, attempt) }
                },
                Task { [weak self] in
                    for await _ in kicks {
                        await self?.drainTranslations(attempt)
                    }
                }
            ]
        } catch { failOnDevice(error, attempt) }
    }

    func stopOnDevice() {
        kick?.finish()
        kick = nil
        onDeviceTasks.forEach { $0.cancel() }
        onDeviceTasks = []
        textTranslator = nil
        if let speech {
            self.speech = nil
            Task { await speech.finish() }
        }
    }

    func failOnDevice(_ failure: Error, _ attempt: Int) {
        guard attempt == generation else { return }
        error = failure.localizedDescription
        state = "Failed"
        onLog?("ondevice_error", ["error": "\(failure)"])
        active = false
        generation += 1
        feed.close()
        pump?.cancel()
        pump = nil
        stopOnDevice()
    }

    func handleSpeech(_ t: SpeechResult, _ attempt: Int) {
        guard attempt == generation else { return }
        let text = t.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isFinal {
            volatileSource = ""
            pendingVolatile = nil
            if !text.isEmpty {
                finalSource = Self.trim(Self.join(finalSource, text, sourceLanguage))
                finalQueue.append(text)
            }
        } else {
            volatileSource = text
            pendingVolatile = text
        }
        source = Self.join(finalSource, volatileSource, sourceLanguage)
        if textTranslator == nil { // Same language: subtitles are the transcript.
            translation = source
            finalQueue = []
            pendingVolatile = nil
            if t.isFinal {
                appendTranscript(source: "", translation: text)
            }
            deltas += 1
            lastDeltaUptime = ProcessInfo.processInfo.systemUptime
        }
        onTextChange?()
        kick?.yield()
    }

    /// One request at a time: finished segments first, then the newest volatile text (older ones are skipped).
    func drainTranslations(_ attempt: Int) async {
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
                if finalQueue.isEmpty, !volatileSource.isEmpty {
                    volatileTranslation = output
                } // else superseded
            } else {
                return
            }
            translation = Self.join(finalTranslation, volatileTranslation, targetLanguage)
            deltas += 1
            lastDeltaUptime = ProcessInfo.processInfo.systemUptime
            onTextChange?()
        }
    }

    func translate(_ text: String, _ translator: OnDeviceTextTranslator, _ attempt: Int) async -> String {
        do { return try await translator.translate(text) } catch TranslationError.notInstalled {
            failOnDevice(OnDeviceError.translationNotInstalled(sourceLanguage, targetLanguage), attempt) // Removed mid-session.
        } catch TranslationError.nothingToTranslate {
        } catch {
            if attempt == generation {
                onLog?("ondevice_translate_error", ["error": "\(error)", "text": text])
            }
        }
        return ""
    }
}
