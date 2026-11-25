import CryptoKit
import Foundation
import Observation

/// App-wide vault state for the current library. Holds the vault key in memory while unlocked.
@MainActor
@Observable
final class VaultSession {

    enum State {
        case needsSetup
        case locked
        case unlocked
    }

    private(set) var state: State = .needsSetup
    private(set) var isSetupComplete = false
    private(set) var isTouchIDEnabled = false
    var autoLockMinutes = 10

    private var store: VaultStore?
    private var vaultKey: SymmetricKey?
    private var lockTask: Task<Void, Never>?
    private var touchAccount = BiometricUnlock.defaultAccount

    var isTouchIDAvailable: Bool {
        BiometricUnlock.isAvailable
    }

    // MARK: Library

    /// Points the session at the vault inside a library folder.
    func attach(to root: URL?) {
        lock()
        guard let root else {
            store = nil
            state = .needsSetup
            isSetupComplete = false
            isTouchIDEnabled = false
            return
        }

        let store = VaultStore.forLibrary(root)
        self.store = store
        touchAccount = Self.touchAccount(for: root)
        state = store.exists ? .locked : .needsSetup
        isSetupComplete = store.isSetupComplete
        isTouchIDEnabled = BiometricUnlock.isEnabled(account: touchAccount)
    }

    /// Each library gets its own Touch ID entry.
    private static func touchAccount(for root: URL) -> String {
        let digest = SHA256.hash(data: Data(root.fileKey.utf8))
        let short = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "vault-\(short)"
    }

    private func requireStore() throws -> VaultStore {
        guard let store else { throw VaultStore.VaultError.notFound }
        return store
    }

    // MARK: Setup

    /// Creates the vault and returns the recovery key to show once.
    func createVault(password: String) async throws -> String {
        await Task.yield()
        let store = try requireStore()
        let key = try store.create(password: password)
        let recovery = try store.makeRecoveryKey(for: key)
        didUnlock(with: key)
        return recovery
    }

    /// Replaces the recovery key. Requires an unlocked vault.
    func makeNewRecoveryKey() throws -> String {
        guard let key = vaultKey else { throw VaultStore.VaultError.wrongPassword }
        return try requireStore().makeRecoveryKey(for: key)
    }

    /// Called when the recovery key was saved. Finishes setup.
    func confirmRecoverySaved() throws {
        try requireStore().confirmRecoverySaved()
        isSetupComplete = true
    }

    // MARK: Unlock and lock

    func unlock(password: String) async throws {
        await Task.yield()
        let key = try requireStore().unlock(password: password)
        didUnlock(with: key)
    }

    func unlockWithTouchID() async throws {
        let key = try await BiometricUnlock.unlock(reason: "unlock your secrets", account: touchAccount)
        didUnlock(with: key)
    }

    func resetPassword(recoveryKey: String, newPassword: String) async throws {
        await Task.yield()
        let store = try requireStore()
        try store.resetPassword(recoveryKey: recoveryKey, newPassword: newPassword)
        let key = try store.unlock(password: newPassword)
        didUnlock(with: key)
    }

    func lock() {
        lockTask?.cancel()
        lockTask = nil
        vaultKey = nil
        if state == .unlocked {
            state = .locked
        }
    }

    private func didUnlock(with key: SymmetricKey) {
        vaultKey = key
        state = .unlocked
        noteActivity()
    }

    // MARK: Touch ID

    func enableTouchID() throws {
        guard let key = vaultKey else { return }
        try BiometricUnlock.enable(vaultKey: key, account: touchAccount)
        isTouchIDEnabled = true
    }

    func disableTouchID() {
        BiometricUnlock.disable(account: touchAccount)
        isTouchIDEnabled = false
    }

    // MARK: Auto-lock

    /// Restarts the auto-lock timer. Call when the user works with secrets.
    func noteActivity() {
        guard state == .unlocked else { return }
        lockTask?.cancel()
        let delay = Duration.seconds(autoLockMinutes * 60)
        lockTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }

    // MARK: Using the key

    /// Encrypts data with the vault key. Fails while locked.
    func seal(_ data: Data) throws -> Data {
        guard let key = vaultKey else { throw VaultStore.VaultError.wrongPassword }
        noteActivity()
        return try VaultCrypto.seal(data, with: key)
    }

    /// Decrypts data with the vault key. Fails while locked.
    func open(_ data: Data) throws -> Data {
        guard let key = vaultKey else { throw VaultStore.VaultError.wrongPassword }
        noteActivity()
        return try VaultCrypto.open(data, with: key)
    }
}