import HearviaKit
import SwiftUI

@main
struct HearviaApp: App {
    @State private var model = AppModel()
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.dark

    var body: some Scene {
        WindowGroup {
            HomeView(model: model, showOnboarding: !onboardingCompleted)
                .tint(.hvAccent)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
