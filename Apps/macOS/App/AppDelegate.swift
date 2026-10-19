import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // The overlay panel usually counts as visible, so always bring the control window forward.
        model?.openWindow?("main")
        return false
    }

    func applicationWillTerminate(_: Notification) {
        model?.translator.saveTranscript()
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        guard let model else { return nil }
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(model.capturing ? String(localized: "Stop Listening") : String(localized: "Start Listening")) {
            Task { await model.toggleListening() }
        })
        let overlay = ActionMenuItem(String(localized: "Show Subtitle Overlay")) { model.settings.overlayVisible.toggle() }
        overlay.state = model.settings.overlayVisible ? .on : .off
        menu.addItem(overlay)
        return menu
    }
}

@MainActor
private final class ActionMenuItem: NSMenuItem {
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
