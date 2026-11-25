import CryptoKit
import Foundation

/// Creates, saves, loads and unlocks the vault header.
struct VaultStore {

    enum VaultError: Error {
        case alreadyExists
        case notFound
        case wrongPassword
        case unsupportedVersion
    }

    let directory: URL

    var fileURL: URL {
        directory.appendingPathComponent("vault.json")
    }

    /// The default store inside the app's private Application Support folder.
    static func standard() throws -> VaultStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return VaultStore(directory: base.appendingPathComponent("MSN", isDirectory: true))
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: Read and write

    func load() throws -> VaultHeader {
        guard exists else { throw VaultError.notFound }
        let data = try Data(contentsOf: fileURL)
        let header = try JSONDecoder().decode(VaultHeader.self, from: data)
        guard header.version <= VaultHeader.currentVersion else { throw VaultError.unsupportedVersion }
        return header
    }

    func save(_ header: VaultHeader) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(header)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: Vault actions

    /// Creates a new vault and returns its unlocked key.
    func create(password: String) throws -> SymmetricKey {
        guard !exists else { throw VaultError.alreadyExists }

        let vaultKey = VaultCrypto.newVaultKey()
        let salt = try VaultCrypto.newSalt()
        let iterations = VaultCrypto.defaultIterations
        let passwordKey = try VaultCrypto.deriveKey(password: password, salt: salt, iterations: iterations)

        let header = VaultHeader(
            version: VaultHeader.currentVersion,
            createdAt: Date(),
            salt: salt,
            iterations: iterations,
            passwordWrappedKey: try VaultCrypto.wrap(vaultKey, with: passwordKey),
            recoverySalt: nil,
            recoveryWrappedKey: nil
        )
        try save(header)
        return vaultKey
    }

    /// Returns the vault key if the password is correct.
    func unlock(password: String) throws -> SymmetricKey {
        let header = try load()
        let passwordKey = try VaultCrypto.deriveKey(
            password: password,
            salt: header.salt,
            iterations: header.iterations
        )
        do {
            return try VaultCrypto.unwrap(header.passwordWrappedKey, with: passwordKey)
        } catch {
            throw VaultError.wrongPassword
        }
    }

    /// Re-locks the vault key with a new password. Stored files are not changed.
    func changePassword(from oldPassword: String, to newPassword: String) throws {
        let vaultKey = try unlock(password: oldPassword)
        var header = try load()

        let salt = try VaultCrypto.newSalt()
        let passwordKey = try VaultCrypto.deriveKey(
            password: newPassword,
            salt: salt,
            iterations: VaultCrypto.defaultIterations
        )

        header.salt = salt
        header.iterations = VaultCrypto.defaultIterations
        header.passwordWrappedKey = try VaultCrypto.wrap(vaultKey, with: passwordKey)
        try save(header)
    }
}