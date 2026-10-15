import SwiftUI

struct Bullet: View {
    let symbol: String
    let text: LocalizedStringKey
    init(_ symbol: String, _ text: LocalizedStringKey) {
        self.symbol = symbol
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 24)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
