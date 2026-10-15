import Foundation

public struct MicrophoneError: LocalizedError {
    public var errorDescription: String? {
        "Microphone access is off. Allow it in Settings → Privacy & Security → Microphone."
    }
}
