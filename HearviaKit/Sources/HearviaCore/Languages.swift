/// Language codes ("en", "zh", "yue") for spoken and subtitle languages.
public enum Languages {
    /// What the Realtime engine supports, most used first. Also the default list before on-device languages load.
    public static let supported = ["zh", "en", "ja", "ko", "es", "fr", "de", "pt", "it", "ru", "hi", "id", "vi"]

    /// Languages written without spaces between words.
    static let unspaced: Set<String> = ["zh", "ja", "yue", "th", "lo", "km", "my"]

    /// Picker choices for `engine`. On-device lists `onDevice` (empty until it loads), Realtime languages first;
    /// `selected` is always included so a picker never loses its current value.
    public static func choices(for engine: EngineKind, onDevice: [String], including selected: String) -> [String] {
        var choices = supported
        if engine == .onDevice, !onDevice.isEmpty {
            let available = Set(onDevice)
            choices = supported.filter(available.contains)
                + available.subtracting(supported).sorted { LanguageName.localized($0) < LanguageName.localized($1) }
        }
        return choices.contains(selected) ? choices : [selected] + choices
    }

    /// `code` when Realtime can show subtitles in it, otherwise English.
    public static func realtimeTarget(for code: String) -> String {
        supported.contains(code) ? code : "en"
    }
}
