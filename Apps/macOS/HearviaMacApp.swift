import HearviaKit
import SwiftUI

@main
struct HearviaMacApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Hearvia", id: "main") {
            ContentView(model: model)
                .task {
                    model.showOverlay()
                    if CommandLine.arguments.contains("--autostart") { await model.start() }
                }
        }
        .windowResizability(.contentSize)

        Window("Transcript", id: "transcript") {
            TranscriptView(translator: model.translator)
        }
        .defaultSize(width: 520, height: 560)

        Settings {
            SettingsView(model: model)
        }

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image(systemName: model.capturing ? "captions.bubble.fill" : "captions.bubble")
                .accessibilityLabel("Hearvia")
        }
    }
}

/// Start, stop and show the overlay without bringing the control window forward.
struct MenuBarContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.capturing ? "Stop Listening" : "Start Listening") {
            Task { model.capturing ? await model.stop() : await model.start() }
        }
        Text("\(model.source.label) → \(LanguageLabel.of(model.translator.targetLanguage)) · \(model.translator.engine.title)")
        Divider()
        Toggle("Show Subtitle Overlay", isOn: $model.overlayVisible)
        Toggle("Click-Through", isOn: $model.clickThrough)
        Divider()
        Button("Open Hearvia") { openWindow(id: "main"); NSApp.activate() }
        Button("Transcript") { openWindow(id: "transcript"); NSApp.activate() }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Hearvia") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
