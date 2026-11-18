import HearviaUI
import SwiftUI

/// SwiftUI's segmented picker displays only the title of each Label on macOS.
struct ThemePicker: NSViewRepresentable {
    @Binding var selection: Appearance

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let options = Appearance.allCases
        let control = NSSegmentedControl(labels: options.map(\.title), trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.selectTheme(_:)))
        for (index, option) in options.enumerated() {
            control.setImage(NSImage(systemSymbolName: option.symbol, accessibilityDescription: nil), forSegment: index)
            control.setImageScaling(.scaleProportionallyDown, forSegment: index)
        }
        control.setAccessibilityLabel(String(localized: "Theme"))
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        control.selectedSegment = Appearance.allCases.firstIndex(of: selection) ?? -1
    }

    @MainActor final class Coordinator: NSObject {
        var selection: Binding<Appearance>
        init(selection: Binding<Appearance>) {
            self.selection = selection
        }

        @objc func selectTheme(_ sender: NSSegmentedControl) {
            let options = Appearance.allCases
            guard options.indices.contains(sender.selectedSegment) else { return }
            selection.wrappedValue = options[sender.selectedSegment]
        }
    }
}

private extension Appearance {
    var symbol: String {
        switch self {
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        case .system: "circle.lefthalf.filled"
        }
    }
}
