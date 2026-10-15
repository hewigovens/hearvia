import AVFoundation
import HearviaUI
import SwiftUI

/// Microphone access: ask in context, or send the user to Settings after a denial.
struct MicrophonePermissionRow: View {
    @State private var permission = AVAudioApplication.shared.recordPermission
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "mic").font(.title3).foregroundStyle(Color.hvAccent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Microphone").font(.subheadline.weight(.semibold))
                Text("For talks, lessons and people around you. Not needed for other apps' sound.")
                    .font(.subheadline).foregroundStyle(Color.hvMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
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
        .padding(16)
        .background(Color.hvSurface, in: .rect(cornerRadius: 16, style: .continuous))
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            permission = AVAudioApplication.shared.recordPermission
        }
    }
}
