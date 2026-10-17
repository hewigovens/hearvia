import Foundation

public enum RetiredFiles {
    /// TranslateGemma's 2.2 GB of weights (removed 2026-10-17); a no-op once they're gone.
    public static func remove() {
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Hearvia/Models"))
    }
}
