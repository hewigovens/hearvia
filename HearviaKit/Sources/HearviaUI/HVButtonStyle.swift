import SwiftUI

/// Filled pill button: accent for primary actions, red for Stop, raised surface for secondary ones.
public struct HVButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, stop, secondary }
    let kind: Kind
    let height: CGFloat
    public init(_ kind: Kind = .primary, height: CGFloat = 56) {
        self.kind = kind
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height >= 50 ? 18 : 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(kind == .primary ? Color.hvOnAccent : kind == .stop ? .white : Color.hvText)
            .background(kind == .primary ? Color.hvAccent : kind == .stop ? Color.hvStop : Color.hvSurface,
                        in: .rect(cornerRadius: height >= 50 ? 18 : 14, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.hvLine)
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}
