import HearviaUI
import SwiftUI

@main
struct HearviaApp: App {
    @UIApplicationDelegateAdaptor private var quickActions: QuickActionAppDelegate
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                .environment(settings)
                .tint(.hvAccent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
