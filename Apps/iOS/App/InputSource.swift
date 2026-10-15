enum InputSource: String, CaseIterable, Identifiable {
    case otherApps, microphone
    var id: String {
        rawValue
    }
    var title: String {
        self == .otherApps ? "Other apps" : "Microphone"
    }
}
