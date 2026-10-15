import HearviaCore

public extension EngineKind {
    var symbol: String {
        self == .onDevice ? "cpu" : "cloud"
    }
}
