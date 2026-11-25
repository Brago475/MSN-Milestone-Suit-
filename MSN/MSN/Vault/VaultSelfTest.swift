#if DEBUG
import CryptoKit
import Foundation

/// Debug-only checks for the vault. Results print to the Xcode console.
enum VaultSelfTest {

    private static var passed = 0
    private static var failed = 0

    private static func check(_ name: String, _ result: Bool) {
        if result {
            passed += 1
            print("  PASS  \(name)")
        } else {
            failed += 1
            print("  FAIL  \(name)")
        }
    }

    private static func bytes(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    static func run() {
        passed = 0
        failed = 0
        print("Vault self-test: starting")
        runCryptoChecks()
        runStoreChecks()
        runRecoveryChecks()
        print("Vault self-test: \(passed) passed, \(failed) failed")
    }

    // MARK: Crypto

    private static func runCryptoChecks() {
        do {
            let message = Data("Milestone Suit test data".utf8)
            let key = VaultCrypto.newVaultKey()

            let sealed = try VaultCrypto.seal(message, with: key)
            let opened = try VaultCrypto.open(sealed, with: key)
            check("seal and open return the same data", opened == message)

            let otherKey = VaultCrypto.newVaultKey()
            check("wrong key is rejected", (try? VaultCrypto.open(sealed, with: otherKey)) == nil)

            var tampered = sealed
            tampered[tampered.count - 1] ^= 0xFF
            check("tampered data is rejected", (try? VaultCrypto.open(tampered, with: key)) == nil)

            let salt = try VaultCrypto.newSalt()
            let start = Date()
            let passwordKey = try VaultCrypto.deriveKey(password: "correct horse", salt: salt)
            print(String(format: "  INFO  password stretching took %.2f s", Date().timeIntervalSince(start)))

            let wrapped = try VaultCrypto.wrap(key, with: passwordKey)
            let unwrapped = try VaultCrypto.unwrap(wrapped, with: passwordKey)
            check("password unlocks the vault key", bytes(unwrapped) == bytes(key))

            let wrongKey = try VaultCrypto.deriveKey(password: "wrong horse", salt: salt)
            check("wrong password is rejected", (try? VaultCrypto.unwrap(wrapped, with: wrongKey)) == nil)
        } catch {
            failed += 1
            print("  FAIL  unexpected crypto error: \(error)")
        }
    }

    // MARK: Store

    private static func makeTempStore() -> VaultStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MSNVaultTest-\(UUID().uuidString)", isDirectory: true)
        return VaultStore(directory: dir)
    }

    private static func runStoreChecks() {
        let store = makeTempStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        do {
            let created = try store.create(password: "first pass")
            let unlocked = try store.unlock(password: "first pass")
            check("vault file saves and unlocks", bytes(created) == bytes(unlocked))

            check("vault file rejects wrong password", (try? store.unlock(password: "nope")) == nil)

            try store.changePassword(from: "first pass", to: "second pass")
            let afterChange = try store.unlock(password: "second pass")
            check("new password unlocks the same vault key", bytes(afterChange) == bytes(created))

            check("old password no longer works", (try? store.unlock(password: "first pass")) == nil)
        } catch {
            failed += 1
            print("  FAIL  unexpected store error: \(error)")
        }
    }

    // MARK: Recovery key

    private static func runRecoveryChecks() {
        let store = makeTempStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        do {
            let sample = try RecoveryKey.generate()
            let groups = sample.split(separator: "-")
            check("recovery key has 6 groups of 4",
                  groups.count == 6 && groups.allSatisfy { $0.count == 4 })
            print("  INFO  sample recovery key \(sample)")

            let vaultKey = try store.create(password: "my pass")
            let recovery = try store.makeRecoveryKey(for: vaultKey)

            let viaRecovery = try store.unlock(recoveryKey: recovery)
            check("recovery key unlocks the vault key", bytes(viaRecovery) == bytes(vaultKey))

            let typed = recovery.lowercased().replacingOccurrences(of: "-", with: " ")
            let viaTyped = try store.unlock(recoveryKey: typed)
            check("recovery key accepts lowercase and spaces", bytes(viaTyped) == bytes(vaultKey))

            let wrongRecovery = try RecoveryKey.generate()
            check("wrong recovery key is rejected", (try? store.unlock(recoveryKey: wrongRecovery)) == nil)

            try store.resetPassword(recoveryKey: recovery, newPassword: "fresh pass")
            let afterReset = try store.unlock(password: "fresh pass")
            check("recovery key resets the password", bytes(afterReset) == bytes(vaultKey))
        } catch {
            failed += 1
            print("  FAIL  unexpected recovery error: \(error)")
        }
    }
}
#endif