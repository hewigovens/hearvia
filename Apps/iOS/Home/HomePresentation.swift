/// What the home screen presents over itself; one at a time.
enum HomePresentation: String, Identifiable {
    case settings, onboarding, source, languages, translator, transcripts
    var id: String {
        rawValue
    }
}
