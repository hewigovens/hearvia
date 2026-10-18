import SwiftUI

/// The iPhone Duo's fold in the layout's own space; every other device has none.
struct DuoPosture {
    let fold: CGRect

    init?(_ proxy: GeometryProxy) {
        guard #available(iOS 27.1, *),
              let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first,
              CGRect(origin: .zero, size: proxy.size).contains(CGPoint(x: region.frame.midX, y: region.frame.midY))
        else { return nil }
        fold = region.frame
    }

    /// Held in portrait the fold runs across: the top half stands up when it's half-folded on a table.
    var isTabletop: Bool {
        fold.width > fold.height
    }
}
