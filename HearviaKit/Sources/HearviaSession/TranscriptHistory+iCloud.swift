import Foundation
import HearviaCore

extension TranscriptHistory {
    public func storageNote(device: String) -> String {
        if isInICloud {
            return String(localized: "Synced across your devices. Deleting syncs too.")
        }
        if syncsWithICloud {
            return String(localized: "Turn on iCloud Drive to sync. Kept on this \(device) meanwhile.")
        }
        return String(localized: "Kept on this \(device) only.")
    }

    func startSync() async {
        guard let cloudContainer, let cloud = await Self.cloudDirectory(cloudContainer) else {
            isInICloud = false // Not signed in to iCloud, or iCloud Drive is off: keep saving locally.
            return
        }
        let local = localDirectory
        await Task.detached { Self.move(from: local, to: cloud) }.value
        guard syncsWithICloud else { return } // Turned off while moving.
        directory = cloud
        isInICloud = true
        startQuery()
    }

    func stopSync() {
        stopQuery()
        guard isInICloud else { return }
        // Keep this device's copy; the iCloud copies stay for the user's other devices.
        directory = localDirectory
        isInICloud = false
        for transcript in transcripts {
            Self.write(transcript, to: file(transcript.id))
        }
    }

    private func startQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)
        let center = NotificationCenter.default
        observers = [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate].map { name in
            center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.queryChanged() }
            }
        }
        self.query = query
        query.start()
    }

    private func stopQuery() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private func queryChanged() {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        var current: [URL] = []
        for case let item as NSMetadataItem in query.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  url.deletingLastPathComponent().lastPathComponent == directory.lastPathComponent else { continue }
            if item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                current.append(url)
            } else {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url) // The query updates once it lands.
            }
        }
        Task { [current] in
            let loaded = await Task.detached { Self.read(files: current) }.value
            guard isInICloud else { return }
            transcripts = loaded
        }
    }

    /// Off the main thread: the first call can take a while.
    private static func cloudDirectory(_ container: String) async -> URL? {
        await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: container)?
                .appending(path: "Transcripts", directoryHint: .isDirectory)
        }.value
    }

    /// Ones already in iCloud win.
    private nonisolated static func move(from local: URL, to cloud: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(at: cloud, withIntermediateDirectories: true)
        let files = (try? manager.contentsOfDirectory(at: local, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            let destination = cloud.appending(path: file.lastPathComponent)
            if manager.fileExists(atPath: destination.path) {
                try? manager.removeItem(at: file)
            } else {
                try? manager.setUbiquitous(true, itemAt: file, destinationURL: destination)
            }
        }
    }
}
