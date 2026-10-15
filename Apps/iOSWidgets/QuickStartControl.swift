import AppIntents
import SwiftUI
import WidgetKit

/// Control Center, Lock Screen and Action button: opens Hearvia and starts listening.
struct QuickStartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dev.hewig.hearvia.control.start") {
            ControlWidgetButton(action: StartListeningIntent()) {
                Label("Start Hearvia", systemImage: "captions.bubble")
            }
        }
        .displayName("Start Hearvia")
        .description("Opens Hearvia and starts live subtitles.")
    }
}
