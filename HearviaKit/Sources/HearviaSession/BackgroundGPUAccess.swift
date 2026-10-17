import Foundation

/// A background GPU grant for one user-started session; late callbacks cannot affect a newer session.
@MainActor
public final class BackgroundGPUAccess {
    public var isGranted: Bool {
        progress != nil
    }
    public private(set) var requestID: String?
    private let supported: Bool
    private let identifierPattern: String
    private let submit: (String) async throws -> Void
    private let cancel: (String) -> Void
    private let log: (String, [String: String]) -> Void
    private var declined = false
    private var progress: Progress?
    private var complete: ((Bool) -> Void)?
    private var lastChunks = 0

    public init(supported: Bool, identifierPattern: String, submit: @escaping (String) async throws -> Void, cancel: @escaping (String) -> Void,
                log: @escaping (String, [String: String]) -> Void = { _, _ in }) {
        self.supported = supported
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
        guard requestID == nil, !declined, supported, foreground else { return }
        let identifier = identifierPattern.replacingOccurrences(of: "*", with: UUID().uuidString)
        requestID = identifier
        do {
            try await submit(identifier)
            if requestID != identifier {
                cancel(identifier)
            }
        } catch {
            guard requestID == identifier else { return }
            finish(success: false)
            declined = true
            log("background_gpu_declined", ["error": error.localizedDescription])
        }
    }

    public func resume() {
        declined = false
    }

    public func stop() {
        finish(success: true)
        declined = false
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
        log("background_gpu_started", [:])
    }

    public func expire(identifier: String) {
        guard requestID == identifier else { return }
        finish(success: false)
        declined = true
        log("background_gpu_expired", [:])
    }

    private func finish(success: Bool) {
        let identifier = requestID
        let complete = complete
        requestID = nil
        self.complete = nil
        if success, let progress {
            progress.completedUnitCount = progress.totalUnitCount
        }
        progress = nil
        if let complete {
            complete(success)
        } else if let identifier {
            cancel(identifier)
        }
    }
}
