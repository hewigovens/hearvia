import Foundation

public struct MicrophoneError: LocalizedError {
    public var errorDescription: String? {
        String(localized: "Microphone access is off. Allow it in Settings → Privacy & Security → Microphone.")
    }
}
