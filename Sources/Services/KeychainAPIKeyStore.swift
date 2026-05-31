import Foundation
import Security

enum KeychainAPIKeyError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainAPIKeyStore {
    private let service = "com.codex.mingsi.glm"
    private let account = "glm_api_key"

    func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        deleteAPIKeyIfPresent()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }

        guard
            let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw KeychainAPIKeyError.invalidData
        }

        return apiKey
    }

    func deleteAPIKey() throws {
        let status = deleteAPIKeyIfPresent()
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    @discardableResult
    private func deleteAPIKeyIfPresent() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        return SecItemDelete(query as CFDictionary)
    }
}
