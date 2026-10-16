import Foundation
import HuggingFace
#if os(iOS)
    import os
#endif

/// TranslateGemma 4B as 4-bit MLX weights from Hugging Face, kept in Application Support/Hearvia/Models.
/// Gemma Terms of Use apply (https://ai.google.dev/gemma/terms).
public enum TranslateGemma {
    public static let repo = "mlx-community/translategemma-4b-it-4bit"
    /// Roughly what `download` fetches, for the UI.
    static let downloadBytes: Int64 = 2_230_000_000
    /// Loading took 2.2 GB on an iPhone 16 Pro and peaked at 2.8 GB on a Mac; the rest is headroom for speech and the app.
    static let requiredMemoryBytes = 3_200_000_000
    /// 8 GB devices: below that the system won't leave an app `requiredMemoryBytes`.
    static let minimumDeviceMemory: UInt64 = 7_000_000_000

    static var hasDeviceMemory: Bool {
        ProcessInfo.processInfo.physicalMemory >= minimumDeviceMemory
    }

    /// What this process may still allocate before iOS ends it; a Mac pages instead, so it always has room.
    static var hasFreeMemory: Bool {
        #if os(iOS)
            os_proc_available_memory() >= requiredMemoryBytes
        #else
            true
        #endif
    }

    public static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Hearvia/Models/translategemma-4b-it-4bit", directoryHint: .isDirectory)
    }

    public static var isDownloaded: Bool {
        isComplete(directory)
    }

    private static func isComplete(_ folder: URL) -> Bool {
        ["config.json", "model.safetensors", "tokenizer.json"].allSatisfy {
            FileManager.default.fileExists(atPath: folder.appending(path: $0).path)
        }
    }

    /// Downloads into a staging folder and moves it into place when complete, so a partial download never looks installed.
    public static func download(progress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        guard !isDownloaded, let id = Repo.ID(rawValue: repo) else { return }
        let staging = directory.deletingLastPathComponent().appending(path: "translategemma.partial", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let hub = HubClient(host: HubClient.defaultHost, cache: nil)
        do {
            _ = try await hub.downloadSnapshot(of: id, to: staging, matching: ["*.json", "*.safetensors"]) { value in
                progress(value.fractionCompleted)
            }
        } catch HubCacheError.snapshotRequiresCacheOrDestination {
            // swift-huggingface 1.0 writes every file to `staging`, then throws this without a cache; a cache would
            // keep a second 2 GB copy.
            guard isComplete(staging) else { throw HubCacheError.snapshotRequiresCacheOrDestination(repo) }
        }
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: staging, to: directory)
    }

    static func remove() throws {
        try FileManager.default.removeItem(at: directory)
    }
}
