import HearviaUI
import SwiftUI

struct FeatureCard: View {
    let symbol: String
    let title: String
    let text: String
    init(_ symbol: String, _ title: String, _ text: String) {
        self.symbol = symbol
        self.title = title
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color.hvAccent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(Color.hvMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }
}
