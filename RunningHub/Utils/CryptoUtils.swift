import Foundation
import CryptoKit
import Security

// MARK: - AES-GCM Encryption
enum CryptoUtils {

    private static let keyTag = "com.runninghub.storagekey"

    // Derive a 256-bit key from a passphrase using SHA-256
    static func deriveKey(from passphrase: String) -> SymmetricKey {
        let data = Data(passphrase.utf8)
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }

    static func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    // Encrypt a Codable object to Data
    static func encryptCodable<T: Codable>(_ value: T, key: SymmetricKey) throws -> Data {
        let plain = try JSONEncoder().encode(value)
        return try encrypt(plain, key: key)
    }

    // Decrypt Data to a Codable object
    static func decryptCodable<T: Codable>(_ data: Data, key: SymmetricKey, as type: T.Type) throws -> T {
        let plain = try decrypt(data, key: key)
        return try JSONDecoder().decode(type, from: plain)
    }

    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
    }
}

// MARK: - Keychain
enum KeychainHelper {

    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
