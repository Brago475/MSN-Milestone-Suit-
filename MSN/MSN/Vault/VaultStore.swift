import CryptoKit
import Foundation

/// Creates, saves, loads and unlocks the vault header.
struct VaultStore {

    enum VaultError: Error {
        case alreadyExists
        case notFound
        case wrongPassword
        case wrongRecoveryKey
        case noRecoveryKey
        case unsupportedVersion
    }

    let directory: URL

    var fileURL: URL {
        directory.appendingPathComponent("vault.json")
    }

    /// The vault stored inside a library folder, in its hidden .msn folder.
    static func forLibrary(_ root: URL) -> VaultStore {
        VaultStore(directory: root.appendingPathComponent(".msn", isDirectory: true))
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    /// True once the recovery key was shown and confirmed as saved.
    var isSetupComplete: Bool {
        (try? load())?.recoveryConfirmed == true
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

    // MARK: Password

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
            recoveryWrappedKey: nil,
            recoveryConfirmed: false
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
        try setPassword(newPassword, for: vaultKey)
    }

    private func setPassword(_ password: String, for vaultKey: SymmetricKey) throws {
        var header = try load()
        let salt = try VaultCrypto.newSalt()
        let passwordKey = try VaultCrypto.deriveKey(
            password: password,
            salt: salt,
            iterations: VaultCrypto.defaultIterations
        )
        header.salt = salt
        header.iterations = VaultCrypto.defaultIterations
        header.passwordWrappedKey = try VaultCrypto.wrap(vaultKey, with: passwordKey)
        try save(header)
    }

    // MARK: Recovery key

    var hasRecoveryKey: Bool {
        (try? load())?.recoveryWrappedKey != nil
    }

    /// Creates a new recovery key for an unlocked vault. Any old recovery key stops working.
    func makeRecoveryKey(for vaultKey: SymmetricKey) throws -> String {
        let display = try RecoveryKey.generate()
        guard let plain = RecoveryKey.normalize(display) else { throw VaultError.wrongRecoveryKey }

        var header = try load()
        let salt = try VaultCrypto.newSalt()
        let recoveryKey = try VaultCrypto.deriveKey(password: plain, salt: salt, iterations: header.iterations)
        header.recoverySalt = salt
        header.recoveryWrappedKey = try VaultCrypto.wrap(vaultKey, with: recoveryKey)
        header.recoveryConfirmed = false
        try save(header)
        return display
    }

    /// Marks the recovery key as saved, which finishes setup.
    func confirmRecoverySaved() throws {
        var header = try load()
        header.recoveryConfirmed = true
        try save(header)
    }

    /// Returns the vault key if the recovery key is correct.
    func unlock(recoveryKey input: String) throws -> SymmetricKey {
        let header = try load()
        guard let salt = header.recoverySalt, let wrapped = header.recoveryWrappedKey else {
            throw VaultError.noRecoveryKey
        }
        guard let plain = RecoveryKey.normalize(input) else { throw VaultError.wrongRecoveryKey }

        let recoveryKey = try VaultCrypto.deriveKey(password: plain, salt: salt, iterations: header.iterations)
        do {
            return try VaultCrypto.unwrap(wrapped, with: recoveryKey)
        } catch {
            throw VaultError.wrongRecoveryKey
        }
    }

    /// Sets a new password using the recovery key. Stored files are not changed.
    func resetPassword(recoveryKey: String, newPassword: String) throws {
        let vaultKey = try unlock(recoveryKey: recoveryKey)
        try setPassword(newPassword, for: vaultKey)
    }
}