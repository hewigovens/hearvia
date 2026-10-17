/// Helpers for the running subtitle strings the engines build up.
public enum SubtitleText {
    /// Joins two pieces of text in `language`, with a space unless the language is written without one.
    public static func join(_ a: String, _ b: String, language: String) -> String {
        if a.isEmpty || b.isEmpty {
            return a + b
        }
        return Languages.unspaced.contains(language) ? a + b : a + " " + b
    }

    /// `delta` as it continues `text` from a new session, which starts without a separator. `unspaced` is the target
    /// language's rule; source text, whose language the cloud engines detect, passes nil to go by the script.
    public static func continuation(of text: String, with delta: String, unspaced: Bool? = nil) -> String {
        guard let last = text.last, let first = delta.first, !last.isWhitespace, !first.isWhitespace else { return delta }
        return (unspaced ?? (last.isUnspacedScript || first.isUnspacedScript)) ? delta : " " + delta
    }

    /// Bounded history; displays show only the tail that fits.
    public static func bounded(_ text: String) -> String {
        text.count > 2000 ? String(text.suffix(1500)) : text
    }
}

private extension Character {
    /// Han, kana and the Southeast Asian scripts that don't put spaces between words.
    var isUnspacedScript: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3000 ... 0x30FF, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF, 0xFF00 ... 0xFFEF,
                 0x0E00 ... 0x0EFF, 0x1000 ... 0x109F, 0x1780 ... 0x17FF: true
            default: false
            }
        }
    }
}
