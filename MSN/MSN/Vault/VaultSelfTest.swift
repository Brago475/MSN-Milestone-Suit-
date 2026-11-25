#if DEBUG
import CryptoKit
import Foundation

/// Debug-only checks for VaultCrypto. Results print to the Xcode console.
enum VaultSelfTest {

    static func run() {
        print("Vault self-test: starting")
        var passed = 0
        var failed = 0

        func check(_ name: String, _ result: Bool) {
            if result {
                passed += 1
                print("  PASS  \(name)")
            } else {
                failed += 1
                print("  FAIL  \(name)")
            }
        }

        do {
            let message = Data("Milestone Suit test data".utf8)
            let key = VaultCrypto.newVaultKey()

            // 1. Round trip
            let sealed = try VaultCrypto.seal(message, with: key)
            let opened = try VaultCrypto.open(sealed, with: key)
            check("seal and open return the same data", opened == message)

            // 2. Wrong key
            let otherKey = VaultCrypto.newVaultKey()
            check("wrong key is rejected", (try? VaultCrypto.open(sealed, with: otherKey)) == nil)

            // 3. Tampered data
            var tampered = sealed
            tampered[tampered.count - 1] ^= 0xFF
            check("tampered data is rejected", (try? VaultCrypto.open(tampered, with: key)) == nil)

            // 4. Password unlocks the vault key
            let salt = try VaultCrypto.newSalt()
            let start = Date()
            let passwordKey = try VaultCrypto.deriveKey(password: "correct horse", salt: salt)
            let elapsed = Date().timeIntervalSince(start)
            print(String(format: "  INFO  password stretching took %.2f s", elapsed))

            let wrapped = try VaultCrypto.wrap(key, with: passwordKey)
            let unwrapped = try VaultCrypto.unwrap(wrapped, with: passwordKey)
            let sameKey = unwrapped.withUnsafeBytes { Data($0) } == key.withUnsafeBytes { Data($0) }
            check("password unlocks the vault key", sameKey)

            // 5. Wrong password
            let wrongKey = try VaultCrypto.deriveKey(password: "wrong horse", salt: salt)
            check("wrong password is rejected", (try? VaultCrypto.unwrap(wrapped, with: wrongKey)) == nil)
        } catch {
            failed += 1
            print("  FAIL  unexpected error: \(error)")
        }

        print("Vault self-test: \(passed) passed, \(failed) failed")
    }
}
#endif