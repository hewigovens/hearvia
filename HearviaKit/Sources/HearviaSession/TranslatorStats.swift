import Foundation

/// Counters for the diagnostics views and logs, reset on each start.
public struct TranslatorStats: Equatable, Sendable {
    /// 200 ms audio chunks the engine accepted.
    public var chunksSent = 0
    /// Translation text changes.
    public var deltas = 0
    public var reconnects = 0
    /// `ProcessInfo.systemUptime` of the last translation change.
    public var lastDeltaUptime: Double?
}
