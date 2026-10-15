import Foundation

struct ProbeSnapshot: Sendable {
    var system = AudioSnapshot()
    var microphone = AudioSnapshot()
    var recordingState = "Idle"
    var recordingURL: URL?
}
