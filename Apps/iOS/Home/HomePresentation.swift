enum HomePresentation: String, Identifiable {
    case settings, onboarding, source, languages, translator, transcripts
    var id: String {
        rawValue
    }
}
