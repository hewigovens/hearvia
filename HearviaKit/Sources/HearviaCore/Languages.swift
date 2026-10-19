public enum Languages {
    public static let supported = ["zh", "en", "ja", "ko", "es", "fr", "de", "pt", "it", "ru", "hi", "id", "vi"]

    /// Gemini Live's subtitle languages (ai.google.dev/gemini-api/docs/live-api/live-translate, 2026-10-17), plus Traditional Chinese.
    public static let gemini = supported + [traditionalChinese, "af", "ak", "am", "ar", "az", "be", "bg", "bn", "ca", "cs", "da", "el", "et", "eu", "fa",
                                            "fi", "fil", "gl", "gu", "ha", "he", "hr", "hu", "hy", "is", "jv", "ka", "kk", "km", "kn",
                                            "lo", "lt", "lv", "mk", "ml", "mn", "mr", "ms", "my", "ne", "nl", "no", "pa", "pl", "ro",
                                            "rw", "sd", "si", "sk", "sl", "sq", "sr", "su", "sv", "sw", "ta", "te", "th", "tr", "uk",
                                            "ur", "uz", "zu"]

    /// A subtitle language only: speech is recognized as "zh", and OpenAI Realtime doesn't offer it.
    public static let traditionalChinese = "zh-Hant"

    /// The script or region providers expect: Simplified Chinese for "zh", Brazilian Portuguese for "pt".
    public static func qualified(_ code: String) -> String {
        switch code {
        case "zh": "zh-Hans"
        case "pt": "pt-BR"
        default: code
        }
    }

    public static let unspaced: Set<String> = ["zh", traditionalChinese, "ja", "yue", "th", "lo", "km", "my"]

    /// `selected` is always included so a picker never loses its current value.
    public static func choices(for engine: EngineKind, onDevice: [String], including selected: String) -> [String] {
        var available = Set(subtitles(for: engine))
        if !engine.isCloud, !onDevice.isEmpty {
            available = Set(onDevice)
        }
        var choices = supported.filter(available.contains)
            + available.subtracting(supported + [traditionalChinese]).sorted { LanguageName.localized($0) < LanguageName.localized($1) }
        if available.contains(traditionalChinese) {
            choices.insert(traditionalChinese, at: (choices.firstIndex(of: "zh") ?? -1) + 1)
        }
        return choices.contains(selected) ? choices : [selected] + choices
    }

    public static func target(_ code: String, for engine: EngineKind) -> String {
        if subtitles(for: engine).contains(code) {
            code
        } else {
            code == traditionalChinese ? "zh" : "en"
        }
    }

    static func subtitles(for engine: EngineKind) -> [String] {
        engine == .gemini || engine == .local ? gemini : supported
    }
}
