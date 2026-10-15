/// Where the OpenAI API key is kept. `KeychainStore` in the apps; an in-memory store in tests.
public protocol SecretStore: Sendable {
    func read() -> String?
    func write(_ value: String)
}
