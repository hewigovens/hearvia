import AVFoundation
import HearviaUI
import SwiftUI

struct MicrophonePermissionRow: View {
    @State private var permission = AVAudioApplication.shared.recordPermission
    @Environment(\.openURL) private var openURL

    var body: some View {
        FeatureCard("mic", "Microphone", "For talks and people around you.", trailing: { control })
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
