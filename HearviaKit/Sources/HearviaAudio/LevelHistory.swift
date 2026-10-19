import Foundation
import Observation

/// The last second of input peaks, ten a second, for the level bars while listening.
@MainActor @Observable
public final class LevelHistory {
    public private(set) var peaks = [Float](repeating: 0, count: 10)
    /// Capture callbacks measure into this from their own queues.
    public nonisolated let meter = LevelMeter()
    @ObservationIgnored private var timer: Timer?

    public init() {}

    public func start() {
        stop()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        peaks = peaks.map { _ in 0 }
    }

    func sample() {
        peaks = Array(peaks.dropFirst()) + [meter.take()]
    }

    #if DEBUG
        /// App Store screenshots (see LiveTranslator+Demo).
        public func loadDemo() {
            peaks = [0.2, 0.5, 0.35, 0.7, 0.45, 0.6, 0.3, 0.55, 0.4, 0.65]
        }
    #endif
}
