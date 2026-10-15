import AppKit

/// Dock behavior: clicking the icon brings back the control window, and its menu mirrors the menu bar extra.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // The overlay panel usually counts as visible, so always bring the control window forward.
        model?.openWindow?("main")
        return false
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        guard let model else { return nil }
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(model.capturing ? "Stop Listening" : "Start Listening") {
            Task { await model.toggleListening() }
        })
        let overlay = ActionMenuItem("Show Subtitle Overlay") { model.settings.overlayVisible.toggle() }
        overlay.state = model.settings.overlayVisible ? .on : .off
        menu.addItem(overlay)
        return menu
    }
}

/// A menu item that runs a closure instead of a target-action selector.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler()
    }
}
