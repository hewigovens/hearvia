import Foundation
import Security

public enum KeychainStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.hewig.Hearvia",
         kSecAttrAccount as String: "openai-api-key"]
    }

    public static func read() -> String? {
        var item: CFTypeRef?
        var q = query
        q[kSecReturnData as String] = true
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func write(_ value: String) {
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var q = query
        q[kSecValueData as String] = Data(value.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
