import SwiftUI

/// The status item's menu while Hearvia is in the Dock, where the control window is the main UI. In menu-bar-only
/// mode the status item opens the control panel instead.
struct MenuBarMenu: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = settings
        Button(model.capturing ? "Stop Listening" : "Start Listening") {
            Task { await model.toggleListening() }
        }
        Text("\(model.source.label) · \(model.translator.languagePair) · \(model.translator.engine.shortTitle)")
        Divider()
        Toggle("Show Subtitle Overlay", isOn: $settings.overlayVisible)
        Divider()
        Button("Open Hearvia") { show("main") }
        Button("Transcripts") { show("transcript") }
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Hearvia") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ window: String) {
        openWindow(id: window)
        NSApp.activate()
    }
}
