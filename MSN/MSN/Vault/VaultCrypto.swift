import CryptoKit
import CommonCrypto
import Foundation

/// Low-level encryption used by the vault.
/// Data is sealed with AES-256-GCM. Passwords are stretched with PBKDF2-SHA256.
enum VaultCrypto {

    static let keySize = 32
    static let saltSize = 16
    static let defaultIterations: UInt32 = 600_000

    enum CryptoError: Error {
        case randomFailed
        case derivationFailed
        case invalidData
    }

    // MARK: Random

    static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw CryptoError.randomFailed }
        return Data(bytes)
    }

    static func newSalt() throws -> Data {
        try randomBytes(saltSize)
    }

    static func newVaultKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // MARK: Password stretching

    /// Derives a 256-bit key from a password and salt.
    static func deriveKey(
        password: String,
        salt: Data,
        iterations: UInt32 = defaultIterations
    ) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: keySize)

        let status = salt.withUnsafeBytes { saltBuffer -> Int32 in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes.map { Int8(bitPattern: $0) },
                passwordBytes.count,
                saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                iterations,
                &derived,
                keySize
            )
        }

        guard status == kCCSuccess else { throw CryptoError.derivationFailed }
        return SymmetricKey(data: derived)
    }

    // MARK: Seal and open

    /// Encrypts data. Output is nonce + ciphertext + tag.
    static func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(data, using: key)
        guard let combined = box.combined else { throw CryptoError.invalidData }
        return combined
    }

    /// Decrypts data produced by `seal`. Fails if the key is wrong or data was changed.
    static func open(_ sealed: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: sealed)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: Key wrapping

    /// Locks the vault key with another key.
    static func wrap(_ vaultKey: SymmetricKey, with wrappingKey: SymmetricKey) throws -> Data {
        let raw = vaultKey.withUnsafeBytes { Data($0) }
        return try seal(raw, with: wrappingKey)
    }

    /// Unlocks the vault key. Fails if the wrapping key is wrong.
    static func unwrap(_ wrapped: Data, with wrappingKey: SymmetricKey) throws -> SymmetricKey {
        let raw = try open(wrapped, with: wrappingKey)
        guard raw.count == keySize else { throw CryptoError.invalidData }
        return SymmetricKey(data: raw)
    }
}