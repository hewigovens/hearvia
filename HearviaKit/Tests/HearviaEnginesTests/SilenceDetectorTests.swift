import Foundation
@testable import HearviaEngines
import Testing

/// 200 ms of a constant sample, so its RMS level is `amplitude` in dBFS terms.
private func steady(_ amplitude: Int16) -> Data {
    [Int16](repeating: amplitude, count: 4800).withUnsafeBytes { Data($0) }
}

@Test func roomNoiseIsSilenceButSpeechIsNot() {
    var detector = SilenceDetector(.roomNoise)
    let room = steady(600) // about -35 dBFS: above the fixed -40 dBFS peak, so the old rule never paused
    let roomSilent = (0 ..< 20).map { _ in detector.isSilent(room) }
    let speechSilent = detector.isSilent(steady(6000)) // 20 dB above the room
    let roomAgain = detector.isSilent(room)
    let digital = detector.isSilent(steady(0))
    #expect(roomSilent.allSatisfy(\.self) && !speechSilent && roomAgain && digital)
}

@Test func peakModeKeepsTheFixedThreshold() {
    var detector = SilenceDetector(.peak(330))
    let loud = detector.isSilent(steady(600)), quiet = detector.isSilent(steady(200))
    #expect(!loud && quiet)
}
