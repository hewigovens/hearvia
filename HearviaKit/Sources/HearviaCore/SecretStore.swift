public protocol SecretStore: Sendable {
    func read(account: String) -> String?
    func write(_ value: String, account: String)
}
