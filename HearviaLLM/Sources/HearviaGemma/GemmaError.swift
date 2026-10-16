import Foundation

enum GemmaError: LocalizedError {
    case notDownloaded
    case notEnoughMemory
    case inBackground

    var errorDescription: String? {
        switch self {
        case .notDownloaded: "Download TranslateGemma in Settings first."
        case .notEnoughMemory: "Not enough free memory for TranslateGemma. Close other apps and try again, or use the on-device translator."
        case .inBackground: "TranslateGemma pauses while Hearvia is behind other apps: iOS doesn't let it use the GPU there."
        }
    }
}
