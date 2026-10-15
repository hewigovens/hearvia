import HearviaUI
import SwiftUI

/// One selectable option in a tile sheet: symbol, title, a line of detail and a check.
struct ChoiceRow: View {
    let symbol: String
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Color.hvAccent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Color.hvText)
                    Text(detail).font(.footnote).foregroundStyle(Color.hvMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.hvAccent : Color.hvLine)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .background(selected ? Color.hvAccentSoft : Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.hvAccent : .clear, lineWidth: 1.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
