import AppKit
import Foundation

/// A vault MSN knows about.
struct VaultRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var bookmark: Data
}

/// Keeps the list of vaults and picks where new vaults go.
enum VaultRegistry {

    private static let listKey = "vaults"
    private static let currentKey = "currentVault"

    /// The real ~/Documents folder, suggested as the starting place for new vaults.
    static var suggestedLocation: URL {
        realHome.appendingPathComponent("Documents", isDirectory: true)
    }

    /// The user's real home folder. Inside the sandbox, the home path points to the app container.
    private static var realHome: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: Stored list

    static func all() -> [VaultRecord] {
        guard let data = UserDefaults.standard.data(forKey: listKey),
              let list = try? JSONDecoder().decode([VaultRecord].self, from: data) else { return [] }
        return list
    }

    private static func saveAll(_ list: [VaultRecord]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    static var currentID: UUID? {
        get { UserDefaults.standard.string(forKey: currentKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: currentKey) }
    }

    // MARK: Register and resolve

    /// Adds or updates a vault in the list with a bookmark to its folder.
    static func register(_ url: URL, info: VaultInfo) throws -> VaultRecord {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let record = VaultRecord(id: info.id, name: info.name, path: url.fileKey, bookmark: bookmark)

        var list = all()
        if let index = list.firstIndex(where: { $0.id == record.id }) {
            list[index] = record
        } else {
            list.append(record)
        }
        saveAll(list)
        return record
    }

    /// Returns the folder for a vault and whether its bookmark needs refreshing.
    static func resolve(_ record: VaultRecord) -> (url: URL, isStale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: record.bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }

    static func refreshBookmark(for id: UUID, url: URL) {
        var list = all()
        guard let index = list.firstIndex(where: { $0.id == id }),
              let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        list[index].bookmark = data
        list[index].path = url.fileKey
        saveAll(list)
    }

    // MARK: Location picker

    /// Asks where to create a vault, starting in Documents. Returns nil if cancelled.
    static func chooseLocation(for name: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a location"
        panel.message = "MSN will create \"\(name)\" inside the folder you choose."
        panel.prompt = "Choose"
        panel.directoryURL = suggestedLocation
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}