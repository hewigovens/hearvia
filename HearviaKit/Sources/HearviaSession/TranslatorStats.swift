import Foundation

public struct TranslatorStats: Equatable, Sendable {
    public var chunksSent = 0
    public var deltas = 0
    public var reconnects = 0
    public var lastDeltaUptime: Double?
}
