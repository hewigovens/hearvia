import HearviaKit
import SwiftUI

struct EngineCard: View {
    let engine: TranslationEngine
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(engine.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.hvText)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.hvAccent : Color.hvLine)
                }
                Text(engine == .onDevice ? "Free · private · works offline" : "Fastest · best quality · ~$2/hour")
                    .font(.footnote).foregroundStyle(Color.hvMuted).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(selected ? Color.hvAccentSoft : Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.hvAccent : Color.hvLine, lineWidth: 1.5))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
