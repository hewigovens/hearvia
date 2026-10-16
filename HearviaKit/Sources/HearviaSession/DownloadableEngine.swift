import HearviaCore
import HearviaEngines

/// An engine whose model the app downloads on demand and runs itself, such as TranslateGemma on MLX, which stays out
/// of the kit. Implementations are `@Observable` so status views follow the download.
@MainActor
public protocol DownloadableEngine: AnyObject {
    var kind: EngineKind { get }
    var downloadBytes: Int64 { get }
    var isDownloaded: Bool { get }
    /// 0...1 while downloading.
    var progress: Double? { get }
    var failure: String { get }
    /// Whether this device has the memory to run it.
    var isSupported: Bool { get }
    func download() async
    func remove()
    func makeEngine(_ request: EngineRequest) -> any TranslationEngine
}
