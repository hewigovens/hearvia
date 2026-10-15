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
        let host = DraggableHostingView(rootView: OverlayView(model: model))
        host.sizingOptions = []
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setVisible(_ visible: Bool) { visible ? orderFrontRegardless() : orderOut(nil) }
}

/// The overlay has no controls, so any click anywhere starts a window drag. Without this the
/// SwiftUI ScrollViews inside swallow mouse-downs and `isMovableByWindowBackground` never fires.
/// Edge resizing is handled by the window frame before hit-testing reaches here.
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override var mouseDownCanMoveWindow: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}

struct OverlayView: View {
    let model: AppModel

    var body: some View {
        let translator = model.translator
        VStack(spacing: 6) {
            if model.showSource, !translator.source.isEmpty {
                bottomAligned(Text(Self.tail(translator.source, 300))
                    .font(.system(size: model.fontSize * 0.55))
                    .foregroundStyle(.white.opacity(0.7)))
                    .frame(height: ceil(model.fontSize * 0.55 * 1.25 * 2)) // two full lines of original speech
            }
            bottomAligned(Text(translator.translation.isEmpty ? placeholder : Self.tail(translator.translation, 400))
                .font(.system(size: model.fontSize, weight: .semibold))
                .foregroundStyle(.white))
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(model.backgroundOpacity)))
        .shadow(color: .black.opacity(0.4), radius: 2)
    }

    private var placeholder: String {
        if !model.translator.error.isEmpty { return model.translator.error }
        return model.capturing ? "Listening… (\(model.translator.state))" : "Hearvia — start capture in the main window"
    }

    /// Newest lines stay pinned to the bottom; older lines scroll off the top.
    /// A non-scrollable ScrollView gives the text unlimited height but clips it to the panel.
    private func bottomAligned(_ text: some View) -> some View {
        ScrollView {
            text.multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    static func tail(_ text: String, _ limit: Int) -> String {
        guard text.count > limit else { return text }
        var tail = text.suffix(limit)
        if let space = tail.firstIndex(of: " "), tail.distance(from: tail.startIndex, to: space) < 20 {
            tail = tail[tail.index(after: space)...]
        }
        return String(tail)
    }
}
