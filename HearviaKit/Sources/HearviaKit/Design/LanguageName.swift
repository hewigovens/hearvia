import Foundation

/// Display names for the app's two-letter language codes.
public enum LanguageName {
    /// The language's own name, plus the name in the user's language when they differ: "日本語 · Japanese".
    public static func of(_ code: String) -> String {
        let native = short(code)
        let local = localized(code)
        return native.localizedCaseInsensitiveCompare(local) == .orderedSame ? native : "\(native) · \(local)"
    }

    /// The language's own name, e.g. "English", "中文", "日本語".
    public static func short(_ code: String) -> String {
        (Locale(identifier: code).localizedString(forLanguageCode: code) ?? code).capitalized
    }

    /// The name in the user's language, e.g. "Japanese".
    public static func localized(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
