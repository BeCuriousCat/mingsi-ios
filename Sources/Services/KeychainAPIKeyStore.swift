import Foundation
import Security

enum KeychainAPIKeyError: Error {
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainAPIKeyStore {
    private let service: String
    private let apiKeyAccount = "glm_api_key"
    private let baseURLAccount = "glm_base_url"
    private let modelNameAccount = "glm_model_name"

    init(service: String = "com.codex.mingsi.glm") {
        self.service = service
    }

    // Keep each wire protocol's credentials separate so switching to Responses
    // does not destroy a user's existing GLM configuration.
    func loadProtocolKind() throws -> GLMClientConfiguration.ProtocolKind {
        guard let raw = try loadString(account: "model_protocol") else { return .openAICompatible }
        guard let kind = GLMClientConfiguration.ProtocolKind(rawValue: raw) else { throw KeychainAPIKeyError.invalidData }
        return kind
    }

    func saveProtocolKind(_ kind: GLMClientConfiguration.ProtocolKind) throws {
        try saveString(kind.rawValue, account: "model_protocol")
    }

    func loadClientConfiguration() throws -> GLMClientConfiguration {
        let kind = try loadProtocolKind()
        let defaults = GLMClientConfiguration()
        let savedURL = try loadBaseURL()
        guard kind != .responses || savedURL?.isEmpty == false else { throw LLMClientError.invalidEndpoint }
        let rawURL = savedURL ?? defaults.baseURL.absoluteString
        guard let url = URL(string: rawURL), url.host != nil,
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { throw LLMClientError.invalidEndpoint }
        let model = try loadModelName() ?? (kind == .responses ? "" : defaults.model)
        return GLMClientConfiguration(baseURL: GLMClientConfiguration.normalizeBaseURL(url, protocolKind: kind),
            model: model, protocolKind: kind)
    }

    private func connectionAccount(_ account: String) throws -> String {
        try loadProtocolKind() == .responses ? "responses_" + account : account
    }

    // MARK: - API Key

    func saveAPIKey(_ apiKey: String) throws {
        try saveString(apiKey, account: connectionAccount(apiKeyAccount))
    }

    func loadAPIKey() throws -> String? {
        try loadString(account: connectionAccount(apiKeyAccount))
    }

    func deleteAPIKey() throws {
        let status = deleteItem(account: try connectionAccount(apiKeyAccount))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Base URL

    func saveBaseURL(_ url: String) throws {
        try saveString(url, account: connectionAccount(baseURLAccount))
    }

    func loadBaseURL() throws -> String? {
        try loadString(account: connectionAccount(baseURLAccount))
    }

    func deleteBaseURL() throws {
        let status = deleteItem(account: try connectionAccount(baseURLAccount))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Model Name

    func saveModelName(_ modelName: String) throws {
        try saveString(modelName, account: connectionAccount(modelNameAccount))
    }

    func loadModelName() throws -> String? {
        try loadString(account: connectionAccount(modelNameAccount))
    }

    func deleteModelName() throws {
        let status = deleteItem(account: try connectionAccount(modelNameAccount))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAPIKeyError.unexpectedStatus(status)
        }
    }

    // MARK: - Private

    private func saveString(_ value: String, account: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainAPIKeyError.unexpectedStatus(update) }

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
