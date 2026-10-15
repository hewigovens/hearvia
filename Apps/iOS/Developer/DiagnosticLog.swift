import Foundation
import OSLog

/// The lock serializes records from capture, UI, and audio-session callbacks.
final class DiagnosticLog: @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private let handle: FileHandle
    private let logger = Logger(subsystem: "dev.hewig.hearvia", category: "experiment")

    init() {
        let directory = URL.documentsDirectory.appending(path: "Evidence", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appending(path: "session-\(UUID().uuidString).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil,
                                       attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        handle = try! FileHandle(forWritingTo: url) // swiftlint:disable:this force_try
        event("session_created", ["log": url.lastPathComponent])
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
        logger.info("\(line, privacy: .public)")
        do { try handle.write(contentsOf: data + Data([10])) } catch { logger.error("Log write failed: \(error.localizedDescription, privacy: .public)") }
    }

    func sync() {
        lock.lock()
        defer { lock.unlock() }
        try? handle.synchronize()
    }
    deinit { try? handle.close() }
}
