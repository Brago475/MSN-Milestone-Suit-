import Foundation

/// Data saved on disk that lets MSN check the master password.
/// It never contains the password or the unlocked vault key.
struct VaultHeader: Codable {
    var version: Int
    var createdAt: Date
    var salt: Data
    var iterations: UInt32
    var passwordWrappedKey: Data
    var recoverySalt: Data?
    var recoveryWrappedKey: Data?
    var recoveryConfirmed: Bool?

    static let currentVersion = 1
}