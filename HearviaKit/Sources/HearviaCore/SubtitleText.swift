/// Helpers for the running subtitle strings the engines build up.
public enum SubtitleText {
    /// Joins two pieces of text in `language`, with a space unless the language is written without one.
    public static func join(_ a: String, _ b: String, language: String) -> String {
        if a.isEmpty || b.isEmpty {
            return a + b
        }
        return Languages.unspaced.contains(language) ? a + b : a + " " + b
    }

    /// Bounded history; displays show only the tail that fits.
    public static func bounded(_ text: String) -> String {
        text.count > 2000 ? String(text.suffix(1500)) : text
    }
}
