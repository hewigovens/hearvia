import SwiftUI

struct SettingsIcon: View {
    let symbol: String
    let color: Color

    init(_ symbol: String, _ color: Color) {
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: .rect(cornerRadius: 7, style: .continuous))
    }
}

extension Label where Title == Text, Icon == SettingsIcon {
    @MainActor init(_ title: LocalizedStringKey, icon: String, color: Color) {
        self.init { Text(title) } icon: { SettingsIcon(icon, color) }
    }
}
