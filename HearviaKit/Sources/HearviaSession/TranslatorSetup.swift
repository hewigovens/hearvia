/// What the chosen translator still needs before it can run, for the setup lines and the tiles' ready dot.
public enum TranslatorSetup: Sendable, Equatable {
    case needsKey
    case keyRejected
    case needsLocalModel
    case needsModels
    /// The provider or local server didn't answer; the reason is ready to show.
    case unreachable(String)
    case ready
}
