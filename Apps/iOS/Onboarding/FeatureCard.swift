import HearviaUI
import SwiftUI

/// Onboarding card: symbol, title and a line of text, with an optional control on the right or content below.
struct FeatureCard<Trailing: View, Footer: View>: View {
    let symbol: String
    let title: String
    let text: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Color.hvAccent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(text).font(.subheadline).foregroundStyle(Color.hvMuted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                trailing
            }
            footer.padding(.leading, 42) // Under the title, past the symbol column.
        }
        .padding(16)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

extension FeatureCard where Trailing == EmptyView, Footer == EmptyView {
    init(_ symbol: String, _ title: String, _ text: String) {
        self.init(symbol: symbol, title: title, text: text, trailing: { EmptyView() }, footer: { EmptyView() })
    }
}

extension FeatureCard where Footer == EmptyView {
    init(_ symbol: String, _ title: String, _ text: String, @ViewBuilder trailing: () -> Trailing) {
        self.init(symbol: symbol, title: title, text: text, trailing: trailing, footer: { EmptyView() })
    }
}

extension FeatureCard where Trailing == EmptyView {
    init(_ symbol: String, _ title: String, _ text: String, @ViewBuilder footer: () -> Footer) {
        self.init(symbol: symbol, title: title, text: text, trailing: { EmptyView() }, footer: footer)
    }
}
