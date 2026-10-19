import Foundation
import Security
import SanjuCore

actor SessionVault: SessionCredentials {
    private let service = (Bundle.main.bundleIdentifier ?? "com.sanju.native") + ".beta-access"
    private let account: String
    init(account: String = "session") { self.account = account }
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    func load() throws -> BetaSession? {
        var request = query; request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.unavailable }
        return try JSONDecoder().decode(BetaSession.self, from: data)
    }
    func save(_ value: BetaSession?) throws {
        guard let value else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.unavailable }; return
        }
        let data = try JSONEncoder().encode(value)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw VaultError.unavailable }
        } else if status != errSecSuccess { throw VaultError.unavailable }
    }
    enum VaultError: LocalizedError {
        case unavailable
        var errorDescription: String? { "内测凭据暂时无法安全保存，请解锁设备后重试。" }
    }
}
