import SwiftUI

/// The status item icon. There is one from launch in both Dock and menu-bar-only modes, so launch work hangs off it; switching modes inserts the other status item, which mustn't launch again.
struct MenuBarLabel: View {
    let model: AppModel
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: model.capturing ? "captions.bubble.fill" : "captions.bubble")
            .accessibilityLabel("Hearvia")
            .task {
                guard delegate.model == nil else { return }
                delegate.model = model
                model.openWindow = { id in
                    openWindow(id: id)
                    NSApp.activate()
                }
                model.settings.applyAppearance()
                model.settings.applyActivationPolicy()
                if model.settings.menuBarOnly {
                    await closeLaunchWindow()
                } else {
                    openWindow(id: "main") // Even if the last session ended with it closed.
                }
                model.showOverlay()
                if CommandLine.arguments.contains("--autostart") {
                    await model.start()
                }
            }
    }

    /// A menu-bar-only app starts without its control window. SwiftUI orders that window in shortly after launch work begins, so wait (briefly) until it is on screen: closing it earlier doesn't stick.
    private func closeLaunchWindow() async {
        for _ in 0 ..< 150 {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" && $0.isVisible }) {
                window.close()
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
