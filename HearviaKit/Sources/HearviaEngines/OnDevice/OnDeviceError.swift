import Foundation
import HearviaCore

public enum OnDeviceError: LocalizedError {
    case speechUnsupported(String)
    case translationUnsupported(String, String)
    case translationNotInstalled(String, String)
    case noSpeechModels

    public var errorDescription: String? {
        switch self {
        case let .speechUnsupported(l): String(localized: "On-device speech recognition doesn't support \(LanguageName.localized(l)).")
        case let .translationUnsupported(s, t): String(localized: "On-device translation from \(LanguageName.localized(s)) to \(LanguageName.localized(t)) isn't supported.")
        case let .translationNotInstalled(s, t): String(localized: "Download the \(LanguageName.localized(s)) → \(LanguageName.localized(t)) translation language first.")
        case .noSpeechModels: String(localized: "Auto-detect needs a downloaded speech language. Choose the spoken language once to download it.")
        }
    }
}
