import CryptoKit
import Foundation
import Observation

/// App-wide vault state. Holds the vault key in memory while unlocked.
@MainActor
@Observable
final class VaultSession {

    enum State {
        case needsSetup
        case locked
        case unlocked
    }

    private(set) var state: State
    private(set) var isTouchIDEnabled = false
    var autoLockMinutes = 10

    private var vaultKey: SymmetricKey?
    private var lockTask: Task<Void, Never>?
    private let store: VaultStore

    init(store: VaultStore) {
        self.store = store
        self.state = store.exists ? .locked : .needsSetup
        self.isTouchIDEnabled = BiometricUnlock.isEnabled()
    }

    convenience init() {
        guard let store = try? VaultStore.standard() else {
            fatalError("Application Support folder is not available.")
        }
        self.init(store: store)
    }

    var isTouchIDAvailable: Bool {
        BiometricUnlock.isAvailable
    }

    // MARK: Setup

    /// Creates the vault and returns the recovery key to show once.
    func createVault(password: String) async throws -> String {
        await Task.yield()
        let key = try store.create(password: password)
        let recovery = try store.makeRecoveryKey(for: key)
        didUnlock(with: key)
        return recovery
    }

    /// Replaces the recovery key. Requires an unlocked vault.
    func makeNewRecoveryKey() throws -> String {
        guard let key = vaultKey else { throw VaultStore.VaultError.wrongPassword }
        return try store.makeRecoveryKey(for: key)
    }

    // MARK: Unlock and lock

    func unlock(password: String) async throws {
        await Task.yield()
        let key = try store.unlock(password: password)
        didUnlock(with: key)
    }

    func unlockWithTouchID() async throws {
        let key = try await BiometricUnlock.unlock(reason: "unlock your secrets")
        didUnlock(with: key)
    }

    func resetPassword(recoveryKey: String, newPassword: String) async throws {
        await Task.yield()
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
        try BiometricUnlock.enable(vaultKey: key)
        isTouchIDEnabled = true
    }

    func disableTouchID() {
        BiometricUnlock.disable()
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