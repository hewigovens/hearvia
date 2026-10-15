import HearviaUI
import SwiftUI

/// Shown before the first Start: what the macOS prompts that follow are for, so the user knows to allow them.
struct PermissionsView: View {
    let model: AppModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                HearviaIcon(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before you start").font(.title3.weight(.semibold))
                    Text("macOS asks once for each way Hearvia listens.").font(.callout).foregroundStyle(Color.hvMuted)
                }
            }
            VStack(spacing: 8) {
                PermissionRow(symbol: "speaker.wave.2", title: "Audio from other apps",
                              detail: "Allow Hearvia to record system audio. It hears the app you pick and never records the screen.",
                              isNext: model.source != .microphone)
                PermissionRow(symbol: "mic", title: "Microphone",
                              detail: "Asked the first time you choose Microphone, to subtitle speech around you.",
                              isNext: model.source == .microphone)
            }
            Text("Hearvia never plays sound or pauses what you're watching. Audio stays on this Mac unless you use OpenAI Realtime. "
                + "You can change access later in System Settings → Privacy & Security.")
                .font(.caption).foregroundStyle(Color.hvMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Not Now") { dismissWindow() }
                    .buttonStyle(HVButtonStyle(.secondary, height: 36))
                    .keyboardShortcut(.cancelAction)
                Button("Continue") {
                    settings.hasExplainedPermissions = true
                    dismissWindow()
                    Task { await model.start() }
                }
                .buttonStyle(HVButtonStyle(.primary, height: 36))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.hvGround)
        .foregroundStyle(Color.hvText)
        .tint(.hvAccent)
        .preferredColorScheme(settings.appearance.colorScheme)
    }
}
