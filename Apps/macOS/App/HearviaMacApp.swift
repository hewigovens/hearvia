import HearviaKit
import SwiftUI

@main
struct HearviaMacApp: App {
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        Window("Hearvia", id: "main") {
            ControlView(model: model)
                .environment(settings)
                .task {
                    model.showOverlay()
                    if CommandLine.arguments.contains("--autostart") {
                        await model.start()
                    }
                }
        }
        .windowResizability(.contentSize)

        Window("Transcript", id: "transcript") {
            TranscriptView(translator: model.translator)
                .environment(settings)
        }
        .defaultSize(width: 520, height: 560)

        Settings {
            SettingsView(model: model)
                .environment(settings)
        }

        MenuBarExtra {
            MenuBarContent(model: model)
                .environment(settings)
        } label: {
            Image(systemName: model.capturing ? "captions.bubble.fill" : "captions.bubble")
                .accessibilityLabel("Hearvia")
        }
    }
}
