import Foundation

public enum LanguageName {
    public static func of(_ code: String) -> String {
        guard !code.isEmpty else { return "Auto-detect" }
        let native = short(code)
        let local = localized(code)
        return native.localizedCaseInsensitiveCompare(local) == .orderedSame ? native : "\(native) · \(local)"
    }

    public static func short(_ code: String) -> String {
        guard !code.isEmpty else { return "Auto" }
        return (Locale(identifier: code).localizedString(forLanguageCode: code) ?? code).capitalized
    }

    public static func pair(source: String, target: String) -> String {
        "\(short(source)) → \(short(target))"
    }

    /// The English name, for prompts: "Japanese", "Chinese".
    public static func english(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    }

    public static func localized(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
