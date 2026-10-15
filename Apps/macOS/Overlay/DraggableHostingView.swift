import AppKit
import SwiftUI

/// The overlay has no controls, so any click anywhere starts a window drag. Without this the
/// SwiftUI ScrollViews inside swallow mouse-downs and `isMovableByWindowBackground` never fires.
/// Edge resizing is handled by the window frame before hit-testing reaches here.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    override var mouseDownCanMoveWindow: Bool {
        true
    }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
