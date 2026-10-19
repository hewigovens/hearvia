import SwiftUI

public struct HVButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, secondary }
    let kind: Kind
    let height: CGFloat
    public init(_ kind: Kind, height: CGFloat) {
        self.kind = kind
        self.height = height
    }

    private var radius: CGFloat {
        height >= 50 ? 18 : 14
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: height >= 50 ? 18 : 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(kind == .primary ? Color.hvOnAccent : Color.hvText)
            .background(kind == .primary ? Color.hvAccent : Color.hvSurface, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hvLine)
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}
