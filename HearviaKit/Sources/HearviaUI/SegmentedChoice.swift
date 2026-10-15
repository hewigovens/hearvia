import SwiftUI

/// Pill segmented control in the Hearvia palette (system segmented controls ignore the tint on macOS).
public struct SegmentedChoice<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: KeyPath<Option, String>
    let symbol: (Option) -> String
    var height: CGFloat = 44

    public init(selection: Binding<Option>, options: [Option], title: KeyPath<Option, String>,
                height: CGFloat = 44, symbol: @escaping (Option) -> String) {
        _selection = selection
        self.options = options
        self.title = title
        self.height = height
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    Label(option[keyPath: title], systemImage: symbol(option))
                        .font(.system(size: height >= 40 ? 15 : 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.hvText : Color.hvMuted)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(selected ? Color.hvSelected : .clear, in: .rect(cornerRadius: height >= 40 ? 10 : 6, style: .continuous))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(height >= 40 ? 4 : 2)
        .background(Color.hvSurface, in: .rect(cornerRadius: height >= 40 ? 14 : 8, style: .continuous))
    }
}
