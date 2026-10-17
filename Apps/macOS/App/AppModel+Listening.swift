extension AppModel {
    /// Until the permission explainer has been shown, Start opens it instead; the explainer's Continue then starts listening.
    func toggleListening() async {
        if capturing {
            await stop()
        } else if settings.hasExplainedPermissions || CommandLine.arguments.contains("--autostart") {
            await start()
        } else {
            openWindow?("permissions")
        }
    }
}
