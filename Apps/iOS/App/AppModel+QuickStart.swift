extension AppModel {
    /// Starts listening for a widget, control or Shortcut, switching the source first when one was given.
    /// A request while already listening (or starting) only brings the app forward.
    func quickStart(_ source: InputSource?) {
        guard !listening, !busy else { return }
        if let source {
            settings.input = source
        }
        Task { await toggleListening() }
    }
}
