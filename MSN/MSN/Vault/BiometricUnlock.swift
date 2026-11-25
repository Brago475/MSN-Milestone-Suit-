import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Stores a copy of the vault key in the Keychain, released only by Touch ID.
enum BiometricUnlock {

    enum BiometricError: Error {
        case unavailable
        case cancelled
        case keychain(OSStatus)
        case invalidData
    }

    nonisolated static let service = "com.thetcwstudio.MSN.vault"
    nonisolated static let defaultAccount = "vault-key"

    /// True when this Mac has Touch ID set up.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    /// True when a Touch ID copy of the key is saved. Does not prompt.
    static func isEnabled(account: String = defaultAccount) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true

        var query = baseQuery(account: account)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Saves the vault key behind Touch ID. Replaces any earlier copy.
    static func enable(vaultKey: SymmetricKey, account: String = defaultAccount) throws {
        guard isAvailable else { throw BiometricError.unavailable }
        disable(account: account)

        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &accessError
        ) else {
            throw BiometricError.keychain(errSecParam)
        }

        var query = baseQuery(account: account)
        query[kSecValueData as String] = vaultKey.withUnsafeBytes { Data($0) }
        query[kSecAttrAccessControl as String] = access

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw BiometricError.keychain(status) }
    }

    /// Shows the Touch ID prompt and returns the vault key.
    static func unlock(reason: String, account: String = defaultAccount) async throws -> SymmetricKey {
        guard isAvailable else { throw BiometricError.unavailable }

        let context = LAContext()
        context.localizedReason = reason

        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        let result: (OSStatus, Data?) = await Task.detached {
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            return (status, item as? Data)
        }.value

        switch result.0 {
        case errSecSuccess:
            guard let data = result.1, data.count == VaultCrypto.keySize else {
                throw BiometricError.invalidData
            }
            return SymmetricKey(data: data)
        case errSecUserCanceled, errSecAuthFailed:
            throw BiometricError.cancelled
        default:
            throw BiometricError.keychain(result.0)
        }
    }

    /// Removes the Touch ID copy of the key.
    @discardableResult
    static func disable(account: String = defaultAccount) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}