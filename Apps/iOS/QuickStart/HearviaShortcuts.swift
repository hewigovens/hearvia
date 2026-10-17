import AppIntents

struct HearviaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartListeningIntent(), phrases: ["Start \(.applicationName)", "Start subtitles in \(.applicationName)"],
                    shortTitle: "Start Listening", systemImageName: "captions.bubble")
    }
}
