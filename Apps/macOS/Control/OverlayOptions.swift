import HearviaUI
import SwiftUI

struct OverlayOptions: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 8) {
            Text("OVERLAY").font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(Color.hvMuted)
            HStack(spacing: 6) {
                Toggle("Visible", isOn: $settings.overlayVisible)
                Toggle(settings.originalLarge ? "Translation" : "Original", isOn: $settings.showsOriginal)
                    .help(settings.originalLarge ? "Show the translation above the original speech" : "Show the original speech above the translation")
                Toggle("Click-through", isOn: $settings.clickThrough)
                    .help("Clicks reach the app underneath; the overlay can't be dragged meanwhile")
            }
            .toggleStyle(ChipToggleStyle())
            HStack(spacing: 10) {
                Image(systemName: "textformat.size.smaller")
                Slider(value: $settings.overlayFontSize, in: AppSettings.overlayFontSizeRange)
                    .accessibilityLabel("Text size")
                Image(systemName: "textformat.size.larger")
            }
            .foregroundStyle(Color.hvMuted)
            .controlSize(.small)
        }
    }
}

private struct ChipToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            configuration.label
                .font(.system(size: 12, weight: on ? .semibold : .medium))
                .foregroundStyle(on ? Color.hvText : Color.hvMuted)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(on ? Color.hvSelected : Color.hvSurface, in: .rect(cornerRadius: 8, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
