import Foundation

/// Which audio counts as silence, to close a cloud socket that bills per connected minute.
struct SilenceDetector {
    /// `peak`: other apps' audio goes digitally quiet, and dialogue over background music must still count as sound.
    /// `roomNoise`: a microphone never goes quiet, so silence is anything close to the background noise it keeps following.
    enum Mode {
        case peak
        case roomNoise
    }

    private let mode: Mode
    private var floor: Double?
    /// About -40 dBFS.
    private static let peakLimit = 330
    /// Speech is well above a room's hum; the floor drops at once and rises 0.25 dB a second at 200 ms chunks.
    private static let margin = 10.0, quietest = -55.0, rise = 0.05

    init(_ mode: Mode) {
        self.mode = mode
    }

    mutating func isSilent(_ chunk: Data) -> Bool {
        switch mode {
        case .peak:
            return Self.peak(of: chunk) < Self.peakLimit
        case .roomNoise:
            let level = Self.level(of: chunk)
            if level >= Self.quietest { // A dropout's digital silence would otherwise pin the floor for minutes.
                floor = min(level, (floor ?? level) + Self.rise)
            }
            return level < max(Self.quietest, (floor ?? level) + Self.margin)
        }
    }

    static func peak(of chunk: Data) -> Int {
        chunk.withUnsafeBytes { raw in
            var peak = 0
            for offset in stride(from: 0, to: raw.count - 1, by: 2) {
                peak = max(peak, abs(Int(raw.loadUnaligned(fromByteOffset: offset, as: Int16.self))))
            }
            return peak
        }
    }

    /// RMS in dBFS; -100 for digital silence.
    static func level(of chunk: Data) -> Double {
        let squares = chunk.withUnsafeBytes { raw in
            stride(from: 0, to: raw.count - 1, by: 2).reduce(0.0) {
                let sample = Double(raw.loadUnaligned(fromByteOffset: $1, as: Int16.self))
                return $0 + sample * sample
            }
        }
        let count = Double(chunk.count / 2)
        guard count > 0, squares > 0 else { return -100 }
        return max(-100, 20 * log10((squares / count).squareRoot() / 32768))
    }
}
