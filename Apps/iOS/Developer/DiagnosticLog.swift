import Foundation
import OSLog

/// Release builds write no file and redact field values in the system log. The lock serializes records from capture, UI, and audio-session callbacks.
final class DiagnosticLog: @unchecked Sendable {
    private let lock = NSLock()
    private let logger = Logger(subsystem: "dev.hewig.hearvia", category: "experiment")
    #if DEBUG
        let url: URL
        private let handle: FileHandle
    #endif

    init() {
        #if DEBUG
            let directory = URL.documentsDirectory.appending(path: "Evidence", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            url = directory.appending(path: "session-\(UUID().uuidString).jsonl")
            FileManager.default.createFile(atPath: url.path, contents: nil,
                                           attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            handle = try! FileHandle(forWritingTo: url) // swiftlint:disable:this force_try
            event("session_created", ["log": url.lastPathComponent])
        #endif
    }

    func event(_ name: String, _ fields: [String: String] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        var record = fields
        record["event"] = name
        record["utc"] = ISO8601DateFormatter().string(from: Date())
        record["uptime"] = String(format: "%.6f", ProcessInfo.processInfo.systemUptime)
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        #if DEBUG
            logger.info("\(line, privacy: .public)")
            do { try handle.write(contentsOf: data + Data([10])) } catch { logger.error("Log write failed: \(error.localizedDescription, privacy: .public)") }
        #else
            logger.info("\(name, privacy: .public) \(line, privacy: .private)")
        #endif
    }

    func sync() {
        #if DEBUG
            lock.lock()
            defer { lock.unlock() }
            try? handle.synchronize()
        #endif
    }

    #if DEBUG
        deinit { try? handle.close() }
    #endif
}
