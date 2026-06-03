import Foundation
import Security

enum KeychainAPIKeyError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainAPIKeyStore {
    private let service = "com.codex.mingsi.glm"
    private let apiKeyAccount = "glm_api_key"
    private let baseURLAccount = "glm_base_url"
    private let modelNameAccount = "glm_model_name"

    // MARK: - API Key

    func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        deleteItem(account: apiKeyAccount)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    func loadAPIKey() throws -> String? {
        try loadString(account: apiKeyAccount)
    }

    func deleteAPIKey() throws {
        let status = deleteItem(account: apiKeyAccount)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Base URL

    func saveBaseURL(_ url: String) throws {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        deleteItem(account: baseURLAccount)

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: baseURLAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    func loadBaseURL() throws -> String? {
        try loadString(account: baseURLAccount)
    }

    func deleteBaseURL() throws {
        let status = deleteItem(account: baseURLAccount)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Model Name

    func saveModelName(_ modelName: String) throws {
        try saveString(modelName, account: modelNameAccount)
    }

    func loadModelName() throws -> String? {
        try loadString(account: modelNameAccount)
    }

    func deleteModelName() throws {
        let status = deleteItem(account: modelNameAccount)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Private

    private func saveString(_ value: String, account: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        deleteItem(account: account)

        let data = Data(trimmed.utf8)
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

    private func loadString(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            throw KeychainAPIKeyError.invalidData
        }

        return string
    }

    @discardableResult
    private func deleteItem(account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
