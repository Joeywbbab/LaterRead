import Foundation
import Security

// ============== Keychain 管理 ==============
class KeychainManager {
    static let shared = KeychainManager()

    func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else {
            return false
        }

        // 先删除旧的
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: Config.keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 添加新的
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: Config.keychainAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: Config.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: Config.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
