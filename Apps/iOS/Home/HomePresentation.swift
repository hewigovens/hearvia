/// What the home screen presents over itself; one at a time.
enum HomePresentation: String, Identifiable {
    case settings, onboarding
    var id: String {
        rawValue
    }
}
