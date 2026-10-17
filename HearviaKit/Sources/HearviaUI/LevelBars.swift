import SwiftUI

public struct LevelBars: View {
    let levels: [Float]
    public init(levels: [Float]) {
        self.levels = levels
    }
    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule().fill(Color.hvAccent)
                    .frame(width: 4, height: max(3, CGFloat(min(1, sqrt(level) * 1.4)) * 24))
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityLabel("Input level")
    }
}
