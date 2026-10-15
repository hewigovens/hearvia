enum SessionMode: String, CaseIterable, Identifiable {
    case playbackMix = "Playback + mix"
    case recordMix = "Play & record + mix"
    case playbackExclusive = "Playback exclusive"
    var id: String {
        rawValue
    }
}
