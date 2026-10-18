import HearviaUI
import SwiftUI

struct PermissionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let isNext: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.hvAccent)
                .frame(width: 32, height: 32)
                .background(Color.hvAccentSoft, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.callout.weight(.semibold))
                    if isNext {
                        Text("ASKED NEXT").font(.caption2.weight(.semibold)).tracking(0.5).foregroundStyle(Color.hvAccent)
                    }
                }
                Text(detail).font(.caption).foregroundStyle(Color.hvMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(isNext ? Color.hvSurface : .clear, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hvLine, lineWidth: isNext ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
    }
}
