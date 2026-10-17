extension AppModel {
    func quickStart(_ source: InputSource?) {
        guard !listening, !busy else { return }
        if let source {
            settings.input = source
        }
        Task { await toggleListening() }
    }
}
