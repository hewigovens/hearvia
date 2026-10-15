/// What the home screen presents over itself; one at a time.
enum HomePresentation: String, Identifiable {
    case settings, onboarding, languages, translator
    var id: String {
        rawValue
    }
}
