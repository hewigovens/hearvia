import Foundation

struct CoreAudioError: LocalizedError {
    let status: OSStatus
    let operation: String
    var errorDescription: String? {
        "\(operation) failed (OSStatus \(status))"
    }
}
