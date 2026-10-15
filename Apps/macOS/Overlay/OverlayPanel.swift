import AppKit
import SwiftUI

/// Floating subtitle window: stays above other apps, including full-screen video,
/// on every Space, without taking focus.
final class OverlayPanel: NSPanel {
    init(model: AppModel) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(960, screen.width - 80), height: 170)
        let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 60)
        super.init(contentRect: NSRect(origin: origin, size: size),
                   styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { standardWindowButton($0)?.isHidden = true }
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        minSize = NSSize(width: 300, height: 60)
        setFrameAutosaveName("HearviaOverlay")
        let host = DraggableHostingView(rootView: OverlayView(model: model).environment(model.settings))
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool {
        false
    }
    override var canBecomeMain: Bool {
        false
    }

    func setVisible(_ visible: Bool) {
        if visible {
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }
}
