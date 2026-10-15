enum InputSource: String, CaseIterable, Identifiable {
    case otherApps, microphone
    var id: String {
        rawValue
    }
    var title: String {
        self == .otherApps ? "Other apps" : "Microphone"
    }
    var symbol: String {
        self == .otherApps ? "square.grid.2x2" : "mic"
    }
    var detail: String {
        self == .otherApps ? "Safari, YouTube, Podcasts keep playing" : "Talks, lessons and people around you"
    }
}
