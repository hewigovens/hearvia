import SwiftUI

/// A stand-in for the floating subtitle frame (720×400 points) that follows the size settings.
struct SubtitleSample: View {
    let scale: Double
    let originalLarge: Bool
    let showsOriginal: Bool

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 720 * scale
            let main = originalLarge ? String(localized: "Original line") : String(localized: "Translated line")
            let second = originalLarge ? String(localized: "Translated line") : String(localized: "Original line")
            VStack(spacing: 6 * unit) {
                if showsOriginal {
                    Text(second).font(.system(size: 32 * unit, weight: .medium)).foregroundStyle(.white.opacity(0.72))
                }
                Text(main).font(.system(size: (showsOriginal ? 48 : 50) * unit, weight: .semibold)).foregroundStyle(.white)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1.8, contentMode: .fit)
        .background(.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityHidden(true)
    }
}
