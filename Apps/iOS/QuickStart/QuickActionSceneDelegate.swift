import UIKit

/// Home Screen quick actions (long-press the app icon) become the same start request as the widget.
/// A quick action arrives at scene connection on a cold launch, or later while the app is running.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem {
            handle(item)
        }
    }

    func windowScene(_: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handle(shortcutItem))
    }

    @discardableResult
    private func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let source = InputSource.allCases.first(where: { item.type == "dev.hewig.hearvia.start.\($0.rawValue)" }) else { return false }
        QuickStart.shared.request = QuickStartRequest(source: source)
        return true
    }
}

/// Only there to give SwiftUI's scenes the quick-action delegate.
final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, configurationForConnecting session: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}
