import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init(model: AppModel) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(1120, screen.width - 80), height: 220)
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
        let pointer = OverlayPointer()
        let host = OverlayHostingView(rootView: OverlayView(model: model, pointer: pointer).environment(model.settings))
        host.pointer = pointer
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

/// Whether the pointer is over the overlay. SwiftUI's hover tracking stops while Hearvia is in the background, which is when the overlay is used, so the hosting view tracks it instead.
@MainActor @Observable
final class OverlayPointer {
    var inside = false
}

/// Tracks the pointer in every app state, and lets the hover controls take the first click: the panel never becomes key.
private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    var pointer: OverlayPointer?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        pointer?.inside = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        pointer?.inside = false
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
