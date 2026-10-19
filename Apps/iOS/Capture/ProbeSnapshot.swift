import Foundation

struct ProbeSnapshot: Sendable {
    var system = AudioSnapshot()
    var microphone = AudioSnapshot()
    var recordingState = "Idle"
    var recordingURL: URL?
}

struct AudioSnapshot: Sendable {
    var buffers = 0
    var seconds = 0.0
    var sampleRate = 0.0
    var channels = 0
    var lastUptime: Double?
    var rms = 0.0
    var peak = 0.0
    var nonZeroPercent = 0.0
    var toneAmplitude = 0.0
    var toneEnergyFraction = 0.0
    var silentBuffers = 0
    var maxGap = 0.0
    var ptsRegressions = 0
    var backgroundSpan = 0.0
    var backgroundPCMSeconds = 0.0
    var backgroundAudibleSeconds = 0.0
    var backgroundMaxGap = 0.0
    var errors = 0

    var age: Double? {
        lastUptime.map { ProcessInfo.processInfo.systemUptime - $0 }
    }
    var logFields: [String: String] {
        ["buffers": "\(buffers)", "pcm_seconds": "\(seconds)", "sample_rate": "\(sampleRate)",
         "channels": "\(channels)", "rms": "\(rms)", "peak": "\(peak)", "nonzero_pct": "\(nonZeroPercent)",
         "tone_1khz_amplitude": "\(toneAmplitude)", "tone_energy_fraction": "\(toneEnergyFraction)",
         "silent_buffers": "\(silentBuffers)", "last_buffer_age": age.map { String($0) } ?? "none",
         "max_gap": "\(maxGap)", "pts_regressions": "\(ptsRegressions)",
         "background_span": "\(backgroundSpan)", "background_pcm_seconds": "\(backgroundPCMSeconds)",
         "background_audible_seconds": "\(backgroundAudibleSeconds)", "background_max_gap": "\(backgroundMaxGap)",
         "decode_errors": "\(errors)"]
    }
}
