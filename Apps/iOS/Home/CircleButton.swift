import HearviaUI
import SwiftUI

struct CircleButton: View {
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .regular)).foregroundStyle(Color.hvMuted)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .accessibilityLabel(label)
    }
}
