import HearviaCore

public extension EngineKind {
    var symbol: String {
        switch self {
        case .onDevice: "cpu"
        case .realtime: "cloud"
        case .gemini: "sparkle"
        case .local: "desktopcomputer"
        }
    }
}
