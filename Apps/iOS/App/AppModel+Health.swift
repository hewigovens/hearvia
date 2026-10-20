import Foundation

extension AppModel {
    /// Once a minute while listening: what decides whether iOS lets a long locked session run, and how warm it gets.
    func logHealth() {
        let info = ProcessInfo.processInfo
        let now = (uptime: info.systemUptime, cpu: info.cpuSeconds)
        let cpu = lastHealth.map { String(format: "%.0f", 100 * (now.cpu - $0.cpu) / (now.uptime - $0.uptime)) } ?? "-"
        lastHealth = now
        log.event("health", ["footprint_mb": String(format: "%.0f", info.footprintMegabytes), "cpu_pct": cpu,
                             "thermal": "\(info.thermalState.rawValue)", "scene": scene,
                             "transcript_lines": "\(translation.transcript.lines.count)"])
    }
}
