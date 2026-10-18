import HearviaUI
import SwiftUI

struct TileSheet<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.weight(.semibold))
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
    }
}
