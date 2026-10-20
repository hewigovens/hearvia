import Foundation
@testable import HearviaEngines
import Testing

// `chunk(_:)` is a constant signal, so its peak and RMS level are its amplitude.

@Test func roomNoiseIsSilenceButSpeechIsNot() {
    var detector = SilenceDetector(.roomNoise)
    let room = chunk(600) // about -35 dBFS: above the fixed -40 dBFS peak, so the peak rule never paused
    let roomSilent = (0 ..< 20).map { _ in detector.isSilent(room) }
    let speechSilent = detector.isSilent(chunk(6000)) // 20 dB above the room
    let roomAgain = detector.isSilent(room)
    #expect(roomSilent.allSatisfy(\.self) && !speechSilent && roomAgain)
}

@Test func aDropoutDoesNotResetTheRoomNoise() {
    var detector = SilenceDetector(.roomNoise)
    let room = chunk(600)
    _ = detector.isSilent(room)
    let dropout = detector.isSilent(chunk(0))
    let roomAfter = detector.isSilent(room)
    #expect(dropout && roomAfter)
}

@Test func peakModeKeepsTheFixedThreshold() {
    var detector = SilenceDetector(.peak)
    let loud = detector.isSilent(chunk(600)), quiet = detector.isSilent(chunk(200))
    #expect(!loud && quiet)
    #expect(SilenceDetector.peak(of: chunk(-1200)) == 1200 && SilenceDetector.peak(of: Data()) == 0)
}
