import HearviaKit
import SwiftUI

struct CircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(Color.hvText)
                .frame(width: 44, height: 44).background(Color.hvSurface, in: .circle)
        }
        .accessibilityLabel(label)
    }
}
