import Foundation

enum GemmaError: LocalizedError {
    case notDownloaded
    case notEnoughMemory

    var errorDescription: String? {
        switch self {
        case .notDownloaded: "Download TranslateGemma in Settings first."
        case .notEnoughMemory: "Not enough free memory for TranslateGemma. Close other apps and try again, or use the on-device translator."
        }
    }
}
