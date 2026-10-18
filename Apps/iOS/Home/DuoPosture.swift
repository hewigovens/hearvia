import SwiftUI

/// The iPhone Duo's fold in the layout's own space; every other device has none.
struct DuoPosture {
    let fold: CGRect
    let halfFolded: Bool

    init?(_ proxy: GeometryProxy, halfFolded: Bool) {
        guard #available(iOS 27.1, *),
              let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first,
              CGRect(origin: .zero, size: proxy.size).contains(CGPoint(x: region.frame.midX, y: region.frame.midY))
        else { return nil }
        fold = region.frame
        self.halfFolded = halfFolded
    }

    /// Half-folded in portrait, so the fold runs across: the top half stands up, the bottom half lies on the table.
    var isTabletop: Bool {
        halfFolded && fold.width > fold.height
    }

    /// Open with the fold down the middle, like a book: the open Duo held in landscape.
    var isBook: Bool {
        fold.height > fold.width
    }
}

extension View {
    /// Whether the iPhone Duo is half-folded; always false elsewhere.
    func onHalfFoldChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(HalfFoldObserver(action: action))
    }
}

private struct HalfFoldObserver: ViewModifier {
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, new in action(new.hinge?.status == .partiallyOpen) }
        } else {
            content
        }
    }
}
