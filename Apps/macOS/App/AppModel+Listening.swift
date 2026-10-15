extension AppModel {
    /// Start or Stop from any control. Until the permission explainer has been shown, Start calls
    /// `explainPermissions` instead; the explainer's Continue then starts listening.
    func toggleListening(explainPermissions: () -> Void) async {
        if capturing {
            await stop()
        } else if settings.hasExplainedPermissions || CommandLine.arguments.contains("--autostart") {
            await start()
        } else {
            explainPermissions()
        }
    }
}
