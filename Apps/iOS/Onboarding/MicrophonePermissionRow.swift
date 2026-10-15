import AVFoundation
import HearviaUI
import SwiftUI

/// Microphone access: ask in context, or send the user to Settings after a denial.
struct MicrophonePermissionRow: View {
    @State private var permission = AVAudioApplication.shared.recordPermission
    @Environment(\.openURL) private var openURL

    var body: some View {
        FeatureCard("mic", "Microphone", "For talks and people around you. Not needed for other apps.", trailing: { control })
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                permission = AVAudioApplication.shared.recordPermission
            }
    }

    @ViewBuilder private var control: some View {
        switch permission {
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly)
                .font(.title3).foregroundStyle(Color.hvReady).accessibilityLabel("Microphone allowed")
        case .denied:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
        default:
            Button("Allow") {
                Task {
                    _ = await AVAudioApplication.requestRecordPermission()
                    permission = AVAudioApplication.shared.recordPermission
                }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color.hvOnAccent)
        }
    }
}
