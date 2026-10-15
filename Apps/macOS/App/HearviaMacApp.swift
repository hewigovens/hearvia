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
            ControlView(model: model)
                .environment(settings)
        }
        .windowResizability(.contentSize)

        Window("Transcript", id: "transcript") {
            TranscriptView(translator: model.translator)
                .environment(settings)
        }
        .defaultSize(width: 520, height: 560)

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
            MenuBarContent(model: model)
                .environment(settings)
        } label: {
            MenuBarLabel(model: model, delegate: delegate)
        }
    }
}
