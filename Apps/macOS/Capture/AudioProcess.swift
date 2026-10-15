import CoreAudio

struct AudioProcess: Identifiable, Hashable, Sendable {
    let id: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let name: String
    let isOutputting: Bool
}
