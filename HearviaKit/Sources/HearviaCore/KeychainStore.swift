import Foundation
import Security

/// API keys in the device Keychain (this device only, available after first unlock).
public struct KeychainStore: SecretStore {
    public init() {}

    /// The data protection keychain (always used on iOS) scopes items to the app's team and bundle ID, so the Mac doesn't prompt when a differently signed build reads them.
    private func query(_ account: String, legacy: Bool = false) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.hewig.Hearvia",
         kSecAttrAccount as String: account,
         kSecUseDataProtectionKeychain as String: !legacy]
    }

    public func read(account: String) -> String? {
        copy(query(account)) ?? migrate(account)
    }

    public func write(_ value: String, account: String) {
        SecItemDelete(query(account) as CFDictionary)
        guard !value.isEmpty else { return }
        var q = query(account)
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    private func copy(_ query: [String: Any]) -> String? {
        var item: CFTypeRef?
        var q = query
        q[kSecReturnData as String] = true
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Earlier Mac builds saved keys in the login keychain; move each one over once, so a key cleared later can't come back from there.
    private func migrate(_ account: String) -> String? {
        let done = "hearvia.keychainMigrated.\(account)"
        guard !UserDefaults.standard.bool(forKey: done) else { return nil }
        UserDefaults.standard.set(true, forKey: done)
        guard let value = copy(query(account, legacy: true)) else { return nil }
        write(value, account: account)
        SecItemDelete(query(account, legacy: true) as CFDictionary)
        return value
    }
}
