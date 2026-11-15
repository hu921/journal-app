import Foundation
import Security
import CryptoKit

/// Keeps the app passcode in the Keychain as a salted hash, on this device only.
enum PasscodeStore {
    private static let service = "com.sarahu.dailyjournal.passcode"
    private static let account = "app-lock"

    static var isSet: Bool { read() != nil }

    static func set(_ code: String) {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let stored = salt + hash(code, salt: salt)
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: stored,
            // Stays on this device; not in backups to other devices or iCloud Keychain.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess { AppLog.error("Saving passcode failed: \(status)") }
    }

    static func verify(_ code: String) -> Bool {
        guard let stored = read(), stored.count > 16 else { return false }
        let salt = stored.prefix(16)
        return Data(stored.dropFirst(16)) == hash(code, salt: Data(salt))
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func hash(_ code: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(code.utf8)))
    }
}
