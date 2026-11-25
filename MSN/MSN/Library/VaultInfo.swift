import Foundation

/// Identity file stored at .msn/info.json. Marks a folder as an MSN vault.
struct VaultInfo: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var format: Int

    static let currentFormat = 1

    static func fileURL(in root: URL) -> URL {
        root.appendingPathComponent(".msn", isDirectory: true).appendingPathComponent("info.json")
    }

    static func read(from root: URL) -> VaultInfo? {
        guard let data = try? Data(contentsOf: fileURL(in: root)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(VaultInfo.self, from: data)
    }

    static func write(_ info: VaultInfo, to root: URL) throws {
        let folder = root.appendingPathComponent(".msn", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(info).write(to: fileURL(in: root), options: .atomic)
    }
}