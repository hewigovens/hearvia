import Foundation
import Observation

/// A background GPU grant for one user-started session; late callbacks cannot affect a newer session.
@MainActor @Observable
public final class BackgroundGPUAccess {
    public enum Status: Equatable, Sendable {
        case unsupported, available, requesting, active, denied, expired
    }

    public let isSupported: Bool
    public private(set) var status: Status
    public var isGranted: Bool {
        status == .active
    }
    public private(set) var requestID: String?
    private let identifierPattern: String
    private let submit: (String) async throws -> Void
    private let cancel: (String) -> Void
    private let log: (String, [String: String]) -> Void
    private var progress: Progress?
    private var complete: ((Bool) -> Void)?
    private var lastChunks = 0

    public init(supported: Bool, identifierPattern: String, submit: @escaping (String) async throws -> Void, cancel: @escaping (String) -> Void,
                log: @escaping (String, [String: String]) -> Void = { _, _ in }) {
        isSupported = supported
        status = supported ? .available : .unsupported
        self.identifierPattern = identifierPattern
        self.submit = submit
        self.cancel = cancel
        self.log = log
    }

    public func update(running: Bool, foreground: Bool, chunks: Int) async {
        guard running else { stop()
            return
        }
        if let progress {
            let consumed = max(0, chunks - lastChunks)
            // Live input has no known end; progress counts audio chunks actually processed by the engine.
            progress.totalUnitCount += Int64(consumed)
            progress.completedUnitCount += Int64(consumed)
        }
        lastChunks = chunks
        guard requestID == nil, status == .available, foreground else { return }
        let identifier = identifierPattern.replacingOccurrences(of: "*", with: UUID().uuidString)
        requestID = identifier
        status = .requesting
        do {
            try await submit(identifier)
            if requestID != identifier {
                cancel(identifier)
            }
        } catch {
            guard requestID == identifier else { return }
            finish(success: false, status: .denied)
            log("background_gpu_declined", ["error": error.localizedDescription])
        }
    }

    public func resume() {
        if status == .denied || status == .expired {
            status = .available
        }
    }

    public func stop() {
        finish(success: true, status: isSupported ? .available : .unsupported)
        lastChunks = 0
    }

    public func accept(identifier: String, progress: Progress, complete: @escaping (Bool) -> Void) {
        guard requestID == identifier, self.progress == nil else { complete(false)
            return
        }
        self.progress = progress
        self.complete = complete
        progress.totalUnitCount = 1
        progress.completedUnitCount = 0
        status = .active
        log("background_gpu_started", [:])
    }

    public func expire(identifier: String) {
        guard requestID == identifier else { return }
        finish(success: false, status: .expired)
        log("background_gpu_expired", [:])
    }

    private func finish(success: Bool, status: Status) {
        let identifier = requestID
        let complete = complete
        requestID = nil
        self.complete = nil
        if success, let progress {
            progress.completedUnitCount = progress.totalUnitCount
        }
        progress = nil
        self.status = status
        if let complete {
            complete(success)
        } else if let identifier {
            cancel(identifier)
        }
    }
}
