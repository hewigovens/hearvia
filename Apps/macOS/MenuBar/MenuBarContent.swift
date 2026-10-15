import HearviaCore
import SwiftUI

/// Start, stop and show the overlay without bringing the control window forward.
struct MenuBarContent: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = settings
        Button(model.capturing ? "Stop Listening" : "Start Listening") {
            Task {
                await model.toggleListening {
                    openWindow(id: "permissions")
                    NSApp.activate()
                }
            }
        }
        Text("\(model.source.label) → \(LanguageName.localized(model.translator.targetLanguage)) · \(model.translator.engine.title)")
        Divider()
        Toggle("Show Subtitle Overlay", isOn: $settings.overlayVisible)
        Toggle("Click-Through", isOn: $settings.clickThrough)
        Divider()
        Button("Open Hearvia") { openWindow(id: "main")
            NSApp.activate()
        }
        Button("Transcript") { openWindow(id: "transcript")
            NSApp.activate()
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Hearvia") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
