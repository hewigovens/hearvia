import Foundation

extension AppModel {
    func logObservation() {
        log.event("manual_observation", ["source": observationSource, "note": observationNote,
                                         "exclude_own_audio": "\(capture.excludeOwnAudio)", "mic": "\(capture.microphoneEnabled)",
                                         "tone": "\(session.tonePlaying)", "session": session.status, "pip": pip.state])
        log.sync()
        observationNote = ""
    }
}
