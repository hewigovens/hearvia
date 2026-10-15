/// Where API keys are kept, one per `account` (`EngineKind.keyAccount`). `KeychainStore` in the apps; an in-memory
/// store in tests.
public protocol SecretStore: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String)
}
