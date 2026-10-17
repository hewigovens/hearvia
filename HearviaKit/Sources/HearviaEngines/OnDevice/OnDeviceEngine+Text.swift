import Foundation
import HearviaCore
import Translation

extension OnDeviceEngine {
    func handleSpeech(_ result: SpeechResult) {
        guard running else { return }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isFinal {
            volatileSource = ""
            pendingVolatile = nil
            if !text.isEmpty {
                finalSource = SubtitleText.bounded(SubtitleText.join(finalSource, text, language: sourceLanguage))
                finalQueue.append(text)
            }
        } else {
            volatileSource = text
            pendingVolatile = text
        }
        guard translate != nil else { // Same language: subtitles are the transcript.
            finalQueue = []
            pendingVolatile = nil
            if result.isFinal, !text.isEmpty {
                finalTranslation = SubtitleText.bounded(SubtitleText.join(finalTranslation, text, language: targetLanguage))
                continuation.yield(.sentence(source: "", translation: text))
            }
            continuation.yield(.text(source: currentSource, translation: SubtitleText.join(finalTranslation, volatileSource, language: targetLanguage)))
            return
        }
        continuation.yield(.text(source: currentSource, translation: currentTranslation))
        kick?.yield()
    }

    /// One request at a time: finished segments first, then the newest volatile text (older ones are skipped).
    func drainTranslations() async {
        while running, let translate {
            if !finalQueue.isEmpty {
                let text = finalQueue.removeFirst()
                let output = await translated(text, with: translate)
                guard running else { return }
                finalTranslation = SubtitleText.bounded(SubtitleText.join(finalTranslation, output, language: targetLanguage))
                volatileTranslation = ""
                continuation.yield(.sentence(source: text, translation: output))
            } else if let text = pendingVolatile {
                pendingVolatile = nil
                let output = await translated(text, with: translate)
                guard running else { return }
                if finalQueue.isEmpty, !volatileSource.isEmpty {
                    volatileTranslation = output
                } // otherwise a newer final segment replaced it
            } else {
                return
            }
            continuation.yield(.text(source: currentSource, translation: currentTranslation))
        }
    }

    private var currentSource: String {
        SubtitleText.join(finalSource, volatileSource, language: sourceLanguage)
    }

    private var currentTranslation: String {
        SubtitleText.join(finalTranslation, volatileTranslation, language: targetLanguage)
    }

    private func translated(_ text: String, with translate: @Sendable (String) async throws -> String) async -> String {
        do {
            let output = try await translate(text)
            if running, !translationProblem.isEmpty {
                translationProblem = ""
                continuation.yield(.status(.translating(onDevice: true))) // Clears the problem.
            }
            return output
        } catch TranslationError.notInstalled {
            fail(OnDeviceError.translationNotInstalled(sourceLanguage, targetLanguage)) // Removed mid-session.
        } catch TranslationError.nothingToTranslate {
        } catch {
            if running {
                continuation.yield(.log("ondevice_translate_error", ["error": "\(error)", "text": text]))
                if error.localizedDescription != translationProblem {
                    translationProblem = error.localizedDescription
                    continuation.yield(.problem(translationProblem))
                }
            }
        }
        return ""
    }
}
