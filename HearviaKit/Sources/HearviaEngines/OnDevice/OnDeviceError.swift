import Foundation
import HearviaCore

public enum OnDeviceError: LocalizedError {
    case speechUnsupported(String)
    case translationUnsupported(String, String)
    case translationNotInstalled(String, String)

    public var errorDescription: String? {
        switch self {
        case let .speechUnsupported(l): "On-device speech recognition doesn't support \(LanguageName.localized(l))."
        case let .translationUnsupported(s, t): "On-device translation from \(LanguageName.localized(s)) to \(LanguageName.localized(t)) isn't supported."
        case let .translationNotInstalled(s, t): "Download the \(LanguageName.localized(s)) → \(LanguageName.localized(t)) translation language first."
        }
    }
}
