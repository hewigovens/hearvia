import Foundation

/// Audio durations are counted in 200 ms chunks; tests shrink everything.
struct CloudTiming: Sendable {
    /// Silence before the socket is closed to stop billing (25 s).
    var silenceChunks = 125
    /// Audio kept while paused and sent first after reopening, so the first words aren't lost (1.6 s).
    var preRollChunks = 8
    /// Audio kept while a socket connects (10 s); anything older is dropped.
    var connectingChunks = 50
    /// Silent stretch that counts as a good moment to rotate the session (0.4 s).
    var pauseChunks = 2
    /// Rotate this long before the session expires, at the next silent moment.
    var rotationLead: TimeInterval = 180
    /// Rotate regardless of speech once the session is this close to expiring.
    var rotationDeadline: TimeInterval = 60
    var maxFailures = 20
    /// How long a closing socket may flush its last text before it is cancelled.
    var closeGrace: Duration = .seconds(5)
    var backoff: @Sendable (_ failures: Int) -> Duration = { .seconds(min(10.0, 0.5 * Double(1 << min($0, 5)))) }
    var now: @Sendable () -> Date = { Date() }
}
