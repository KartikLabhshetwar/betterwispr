import Foundation
import Security

public struct SpeechAPIKeyStore: Sendable {
    private let service: String

    public init(service: String = "com.betterwispr.speech-api") { self.service = service }

    public func read(for connection: SpeechConnection) throws -> String? {
        var query = query(for: connection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { throw SpeechAPIError.keychain(status) }
        return key
    }

    public func save(_ key: String, for connection: SpeechConnection) throws {
        let query = query(for: connection)
        guard !key.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw SpeechAPIError.keychain(status) }
            return
        }
        let values = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var item = query.merging(values) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SpeechAPIError.keychain(status) }
    }

    private func query(for connection: SpeechConnection) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: connection.keychainAccount,
         kSecAttrSynchronizable as String: false]
    }
}
