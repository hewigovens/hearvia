import SwiftUI

/// One of the setup tiles beside the listen button: what to listen to, languages, translator.
/// Apps wrap it in a `Menu` or `Button`; `ready` adds a green or orange dot. A value that must not wrap
/// (CJK breaks between any two characters) passes `wraps: false` and shrinks instead.
public struct ControlTile: View {
    let symbol: String
    let caption: String
    let value: String
    let ready: Bool?
    let wraps: Bool

    public init(symbol: String, caption: String, value: String, ready: Bool? = nil, wraps: Bool = true) {
        self.symbol = symbol
        self.caption = caption
        self.value = value
        self.ready = ready
        self.wraps = wraps
    }

    #if os(macOS)
        private let height: CGFloat = 84, padding: CGFloat = 10, radius: CGFloat = 12, iconRow: CGFloat = 18
        private let symbolFont = Font.system(size: 15, weight: .medium), valueFont = Font.system(size: 13, weight: .semibold)
    #else
        private let height: CGFloat = 104, padding: CGFloat = 14, radius: CGFloat = 18, iconRow: CGFloat = 24
        private let symbolFont = Font.system(size: 20, weight: .medium), valueFont = Font.system(size: 16, weight: .semibold)
    #endif

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: symbol).font(symbolFont).foregroundStyle(Color.hvAccent)
                Spacer()
                if let ready {
                    Circle().fill(ready ? Color.hvReady : Color.hvAttention).frame(width: 8, height: 8)
                        .accessibilityLabel(ready ? "Ready" : "Needs setup")
                }
            }
            .frame(height: iconRow) // Symbols differ in height; keep the captions level across tiles.
            Spacer().frame(height: padding)
            Text(caption).font(.caption).foregroundStyle(Color.hvMuted)
            Text(value).font(valueFont).foregroundStyle(Color.hvText).lineLimit(wraps ? 2 : 1).minimumScaleFactor(wraps ? 0.8 : 0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.hvSurface, in: .rect(cornerRadius: radius, style: .continuous))
        .contentShape(.rect(cornerRadius: radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
