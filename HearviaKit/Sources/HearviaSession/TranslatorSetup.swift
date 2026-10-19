/// What the chosen translator still needs before it can run, for the setup lines and the tiles' ready dot.
public enum TranslatorSetup: Sendable {
    case needsKey
    case needsLocalModel
    case needsModels
    case ready
}
