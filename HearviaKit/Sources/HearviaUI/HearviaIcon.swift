import SwiftUI

/// App icon tile with the iOS continuous-corner mask.
public struct HearviaIcon: View {
    let size: CGFloat
    public init(size: CGFloat) {
        self.size = size
    }
    public var body: some View {
        HearviaMark()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}
