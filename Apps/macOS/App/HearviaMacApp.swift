import HearviaCore
import SwiftUI

@main
struct HearviaMacApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        Window("Hearvia", id: "main") {
            ControlPanel(model: model, inMenuBar: false)
                .environment(settings)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Transcripts", id: "transcript") {
            TranscriptView(translator: model.translator)
                .environment(settings)
        }
        .defaultSize(width: 760, height: 560)

        Window("Before You Start", id: "permissions") {
            PermissionsView(model: model)
                .environment(settings)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(model: model)
                .environment(settings)
        }

        MenuBarExtra {
            ControlPanel(model: model, inMenuBar: true)
                .environment(settings)
        } label: {
            MenuBarLabel(model: model, delegate: delegate)
        }
        .menuBarExtraStyle(.window)
    }
}
