import HearviaSession
import HearviaUI
import SwiftUI

struct BackgroundTranslationStatus: View {
    let access: BackgroundGPUAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: access.isGranted ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(access.isGranted ? Color.hvReady : Color.hvMuted)
            Text(detail).foregroundStyle(Color.hvMuted)
        }
        .font(.footnote)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var title: String {
        switch access.status {
        case .unsupported: "Background translation unavailable"
        case .available: "Background translation supported"
        case .requesting: "Requesting background access…"
        case .active: "Background translation active"
        case .denied: "Background access unavailable"
        case .expired: "Background access ended"
        }
    }

    private var detail: String {
        switch access.status {
        case .unsupported:
            "On this device, TranslateGemma pauses behind other apps. Keep Hearvia open, or choose On-device for offline subtitles behind other apps."
        case .available:
            "Hearvia asks iOS for access when you start listening. iOS can decline or end access during a session."
        case .requesting:
            "Keep Hearvia open until iOS allows background translation."
        case .active:
            "TranslateGemma can keep translating behind other apps while iOS allows it."
        case .denied, .expired:
            "Keep Hearvia open to translate. Return to Hearvia or start a new session to try background access again."
        }
    }
}
