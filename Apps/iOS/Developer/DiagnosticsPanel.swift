import SwiftUI

struct DiagnosticsPanel: View {
    let stats: AudioSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(format: "%.0f Hz · %d ch · %d buffers · %.2f s PCM", stats.sampleRate, stats.channels, stats.buffers, stats.seconds))
            Text(String(format: "RMS %.6f · peak %.6f · non-zero %.2f%%", stats.rms, stats.peak, stats.nonZeroPercent))
            Text("Last buffer: \(stats.age.map { String(format: "%.2f s ago", $0) } ?? "never") · silent buffers: \(stats.silentBuffers)")
            Text(String(format: "1 kHz amplitude %.6f · energy %.2f%%", stats.toneAmplitude, 100 * stats.toneEnergyFraction))
            Text(String(format: "Max gap %.3f s · PTS regressions %d · decode errors %d", stats.maxGap, stats.ptsRegressions, stats.errors))
            Text(String(format: "Background: span %.1f s · PCM %.1f s · audible %.1f s · max gap %.3f s", stats.backgroundSpan, stats.backgroundPCMSeconds, stats.backgroundAudibleSeconds, stats.backgroundMaxGap))
        }.font(.system(.caption, design: .monospaced)).textSelection(.enabled)
    }
}
