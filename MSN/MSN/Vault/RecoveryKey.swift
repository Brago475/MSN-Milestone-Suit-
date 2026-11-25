import Foundation

/// Creates and reads recovery keys in the form XXXX-XXXX-XXXX-XXXX-XXXX-XXXX.
enum RecoveryKey {

    /// 32 characters without look-alikes (no 0, O, 1, I).
    static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    static let groupCount = 6
    static let groupLength = 4
    static var length: Int { groupCount * groupLength }

    /// Returns a new random key, formatted with dashes.
    static func generate() throws -> String {
        let bytes = try VaultCrypto.randomBytes(length)
        // 256 is a multiple of 32, so this mapping has no bias.
        let characters = bytes.map { alphabet[Int($0) % alphabet.count] }
        return format(String(characters))
    }

    /// Splits a plain key into dashed groups.
    static func format(_ plain: String) -> String {
        var groups: [String] = []
        var index = plain.startIndex
        while index < plain.endIndex {
            let end = plain.index(index, offsetBy: groupLength, limitedBy: plain.endIndex) ?? plain.endIndex
            groups.append(String(plain[index..<end]))
            index = end
        }
        return groups.joined(separator: "-")
    }

    /// Cleans typed input. Returns nil if it is not a valid key.
    static func normalize(_ input: String) -> String? {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == length, cleaned.allSatisfy({ alphabet.contains($0) }) else {
            return nil
        }
        return cleaned
    }
}