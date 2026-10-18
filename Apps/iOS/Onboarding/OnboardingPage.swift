import HearviaUI
import SwiftUI

struct OnboardingPage<Content: View>: View {
    let symbol: String?
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Group {
                    if let symbol {
                        Image(systemName: symbol).font(.system(size: 52)).foregroundStyle(.tint)
                    } else {
                        HearviaIcon(size: 96).shadow(color: .black.opacity(0.35), radius: 16, y: 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                Text(title).font(.title.bold()).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                Text(message).font(.body).foregroundStyle(Color.hvMuted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 14) { content }.padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
