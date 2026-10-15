/// What the home screen presents over itself; one at a time.
enum HomePresentation: String, Identifiable {
    case settings, onboarding, source, languages, translator, transcript
    var id: String {
        rawValue
    }
}
