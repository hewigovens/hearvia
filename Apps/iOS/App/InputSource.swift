enum InputSource: String, CaseIterable, Identifiable, Sendable {
    case otherApps, microphone
    var id: String {
        rawValue
    }
    var title: String {
        self == .otherApps ? String(localized: "Other apps") : String(localized: "Microphone")
    }
    var symbol: String {
        self == .otherApps ? "square.grid.2x2" : "mic"
    }
    var detail: String {
        self == .otherApps ? String(localized: "Safari, YouTube, Podcasts keep playing") : String(localized: "Talks, lessons and people around you")
    }
}
