import Foundation

public enum LanguageName {
    public static func of(_ code: String) -> String {
        guard !code.isEmpty else { return String(localized: "Auto-detect") }
        let native = short(code)
        let local = localized(code)
        return native.localizedCaseInsensitiveCompare(local) == .orderedSame ? native : "\(native) · \(local)"
    }

    public static func short(_ code: String) -> String {
        guard !code.isEmpty else { return String(localized: "Auto") }
        return (Locale(identifier: code).localizedString(forIdentifier: code) ?? code).capitalized
    }

    public static func pair(source: String, target: String) -> String {
        "\(short(source)) → \(short(target))"
    }

    /// The English name, for prompts: "Japanese", "Chinese".
    public static func english(_ code: String) -> String {
        code == Languages.traditionalChinese ? "Traditional Chinese" : Locale(identifier: "en").localizedString(forIdentifier: code) ?? code
    }

    public static func localized(_ code: String) -> String {
        Locale.current.localizedString(forIdentifier: code)?.capitalized ?? code
    }
}
