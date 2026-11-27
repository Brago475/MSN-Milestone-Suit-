import AppKit
import Foundation
import Observation

/// The open vault folder, its file tree, open tabs, and file actions.
@MainActor
@Observable
final class LibraryStore {

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case modified = "Date Modified"
    }

    enum LibraryError: LocalizedError {
        case invalidName
        case nameTaken
        case folderExists
        case invalidMove
        case missing
        case noLibrary

        var errorDescription: String? {
            switch self {
            case .invalidName: "Names can't be empty, start with a period, or contain / or :."
            case .nameTaken: "An item with that name already exists in this folder."
            case .folderExists: "A folder with that name already exists in this location."
            case .invalidMove: "A folder can't be moved into itself."
            case .missing: "This vault's folder can't be found."
            case .noLibrary: "No vault is open."
            }
        }
    }

    private(set) var rootURL: URL?
    private(set) var vaults: [VaultRecord] = []
    private(set) var nodes: [FileNode] = []
    private(set) var index: [String: FileNode] = [:]
    var selection: String?
    var expanded: Set<String> = []
    var sortOrder: SortOrder = .name {
        didSet { reload() }
    }
    var lastError: String?

    /// Open files as tabs, by file key, in order.
    var tabs: [String] = []
    /// The tab showing in the page area.
    var activeTab: String?
    /// A file waiting for a name from the tab bar.
    var renameRequest: URL?

    private var isAccessing = false
    private let fileManager = FileManager.default

    init() {
        vaults = VaultRegistry.all()
        if let id = VaultRegistry.currentID, let record = vaults.first(where: { $0.id == id }) {
            try? open(record)
        }
    }

    var hasLibrary: Bool { rootURL != nil }
    var libraryName: String { rootURL?.lastPathComponent ?? "" }
    var selectedNode: FileNode? { selection.flatMap { index[$0] } }
    var activeNode: FileNode? { activeTab.flatMap { index[$0] } }

    /// Where new items go: the selected folder, the selected file's folder, or the root.
    var targetFolder: URL? {
        guard let rootURL else { return nil }
        guard let node = selectedNode else { return rootURL }
        return node.isFolder ? node.url : node.url.deletingLastPathComponent()
    }

    /// True when the URL is inside the open vault.
    func isInsideVault(_ url: URL) -> Bool {
        guard let rootKey = rootURL?.fileKey else { return false }
        return url.fileKey.hasPrefix(rootKey + "/")
    }

    // MARK: Vaults

    /// Creates a named vault folder inside the chosen location and opens it.
    @discardableResult
    func createVault(named name: String, in location: URL) throws -> URL {
        let clean = try Self.validName(name)
        let folder = location.appendingPathComponent(clean, isDirectory: true)

        if fileManager.fileExists(atPath: folder.path(percentEncoded: false)) {
            throw LibraryError.folderExists
        }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: false)

        let info = VaultInfo(id: UUID(), name: clean, createdAt: Date(), format: VaultInfo.currentFormat)
        try VaultInfo.write(info, to: folder)

        let record = try VaultRegistry.register(folder, info: info)
        vaults = VaultRegistry.all()
        try open(record)
        return folder
    }

    /// Opens a known vault and brings back its tabs.
    func open(_ record: VaultRecord) throws {
        guard let resolved = VaultRegistry.resolve(record) else { throw LibraryError.missing }

        stopAccess()
        isAccessing = resolved.url.startAccessingSecurityScopedResource()

        guard fileManager.fileExists(atPath: resolved.url.path(percentEncoded: false)) else {
            if isAccessing {
                resolved.url.stopAccessingSecurityScopedResource()
                isAccessing = false
            }
            throw LibraryError.missing
        }

        if resolved.isStale {
            VaultRegistry.refreshBookmark(for: record.id, url: resolved.url)
        }

        rootURL = resolved.url
        VaultRegistry.currentID = record.id
        selection = nil
        expanded = []
        tabs = []
        activeTab = nil
        reload()
        restoreTabs()
    }

    private func stopAccess() {
        if isAccessing {
            rootURL?.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    // MARK: Names

    static func isValidName(_ name: String) -> Bool {
        (try? validName(name)) != nil
    }

    static func validName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.hasPrefix("."), !clean.contains("/"), !clean.contains(":") else {
            throw LibraryError.invalidName
        }
        return clean
    }

    // MARK: Tree

    func reload() {
        guard let rootURL else {
            nodes = []
            index = [:]
            tabs = []
            activeTab = nil
            return
        }
        nodes = scan(rootURL)

        var map: [String: FileNode] = [:]
        func add(_ list: [FileNode]) {
            for node in list {
                map[node.id] = node
                add(node.children)
            }
        }
        add(nodes)
        index = map

        if let selection, map[selection] == nil {
            self.selection = nil
        }
        pruneTabs()
    }

    private func scan(_ folder: URL) -> [FileNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey]
        guard let items = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let list: [FileNode] = items.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let modified = values?.contentModificationDate ?? .distantPast
            if values?.isPackage == true { return nil }
            if values?.isDirectory == true {
                return FileNode(url: url, kind: .folder, children: scan(url), modified: modified)
            }
            guard let kind = FileNode.kind(for: url) else { return nil }
            return FileNode(url: url, kind: kind, children: [], modified: modified)
        }
        return sorted(list)
    }

    private func sorted(_ list: [FileNode]) -> [FileNode] {
        list.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            switch sortOrder {
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .modified: return a.modified > b.modified
            }
        }
    }

    /// Rows to show. With search matches, every matching branch is open.
    func visibleRows(matching matches: Set<String>?) -> [TreeRow] {
        var rows: [TreeRow] = []
        func walk(_ list: [FileNode], depth: Int) {
            for node in list {
                if let matches, !matches.contains(node.id) { continue }
                rows.append(TreeRow(node: node, depth: depth))
                if node.isFolder && (matches != nil || expanded.contains(node.id)) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(nodes, depth: 0)
        return rows
    }

    func toggle(_ node: FileNode) {
        if expanded.contains(node.id) {
            expanded.remove(node.id)
        } else {
            expanded.insert(node.id)
        }
    }

    func collapseAll() {
        expanded.removeAll()
    }

    func expandAncestors(of url: URL) {
        guard let rootKey = rootURL?.fileKey else { return }
        var parent = url.deletingLastPathComponent()
        while parent.fileKey.hasPrefix(rootKey) && parent.fileKey != rootKey {
            expanded.insert(parent.fileKey)
            parent = parent.deletingLastPathComponent()
        }
    }

    func relativePath(of url: URL) -> String {
        guard let rootKey = rootURL?.fileKey else { return url.lastPathComponent }
        let key = url.fileKey
        guard key.hasPrefix(rootKey + "/") else { return url.lastPathComponent }
        return String(key.dropFirst(rootKey.count + 1))
    }

    // MARK: Search

    /// Files whose name or text matches, plus their folders.
    func matches(for query: String) -> Set<String> {
        let term = query.trimmingCharacters(in: .whitespaces)
        var result = Set<String>()

        func insertAll(_ node: FileNode) {
            result.insert(node.id)
            node.children.forEach(insertAll)
        }

        func visit(_ node: FileNode) -> Bool {
            if node.isFolder {
                if node.name.localizedCaseInsensitiveContains(term) {
                    insertAll(node)
                    return true
                }
                var hit = false
                for child in node.children where visit(child) {
                    hit = true
                }
                if hit { result.insert(node.id) }
                return hit
            }

            var hit = node.name.localizedCaseInsensitiveContains(term)
            if !hit, node.kind != .pdf,
               let text = try? String(contentsOf: node.url, encoding: .utf8) {
                hit = text.localizedCaseInsensitiveContains(term)
            }
            if hit { result.insert(node.id) }
            return hit
        }

        for node in nodes {
            _ = visit(node)
        }
        return result
    }

    // MARK: File actions

    @discardableResult
    func createNote(in folder: URL? = nil) throws -> URL {
        guard let parent = folder ?? targetFolder else { throw LibraryError.noLibrary }
        let url = uniqueURL(named: "Untitled", pathExtension: "md", in: parent)
        try Data().write(to: url, options: .withoutOverwriting)
        finishCreate(url)
        return url
    }

    @discardableResult
    func createFolder(in folder: URL? = nil) throws -> URL {
        guard let parent = folder ?? targetFolder else { throw LibraryError.noLibrary }
        let url = uniqueURL(named: "New Folder", pathExtension: nil, in: parent)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        finishCreate(url)
        return url
    }

    private func finishCreate(_ url: URL) {
        reload()
        expandAncestors(of: url)
        selection = url.fileKey
    }

    /// Renames a file or folder. Files keep their extension.
    @discardableResult
    func rename(_ url: URL, to newName: String) throws -> URL {
        let clean = try Self.validName(newName)

        let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        var target = url.deletingLastPathComponent().appendingPathComponent(clean, isDirectory: isFolder)
        let ext = url.pathExtension
        if !isFolder, !ext.isEmpty, !clean.lowercased().hasSuffix("." + ext.lowercased()) {
            target = target.appendingPathExtension(ext)
        }

        guard target.fileKey != url.fileKey else { return url }
        let caseOnly = target.fileKey.lowercased() == url.fileKey.lowercased()
        if !caseOnly && fileManager.fileExists(atPath: target.path(percentEncoded: false)) {
            throw LibraryError.nameTaken
        }

        try fileManager.moveItem(at: url, to: target)
        remapKeys(from: url.fileKey, to: target.fileKey)
        reload()
        return target
    }

    /// Moves a file or folder into another folder of the vault.
    @discardableResult
    func move(_ url: URL, into folder: URL) throws -> URL {
        let sourceKey = url.fileKey
        let folderKey = folder.fileKey
        guard folderKey != sourceKey, !folderKey.hasPrefix(sourceKey + "/") else {
            throw LibraryError.invalidMove
        }
        guard url.deletingLastPathComponent().fileKey != folderKey else { return url }

        let target = folder.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: target.path(percentEncoded: false)) {
            throw LibraryError.nameTaken
        }

        try fileManager.moveItem(at: url, to: target)
        remapKeys(from: sourceKey, to: target.fileKey)
        if folderKey != rootURL?.fileKey {
            expanded.insert(folderKey)
        }
        expandAncestors(of: target)
        reload()
        return target
    }

    /// Copies files and folders from outside the vault into a vault folder.
    /// Only Markdown, text and PDF files are added. Originals are not changed.
    func importItems(_ urls: [URL], into folder: URL) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0
        var last: URL?

        for source in urls {
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }

            let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isFolder || FileNode.kind(for: source) != nil else {
                skipped += 1
                continue
            }

            let base = isFolder ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
            let target = uniqueURL(named: base, pathExtension: isFolder ? nil : source.pathExtension, in: folder)
            do {
                try fileManager.copyItem(at: source, to: target)
                imported += 1
                last = target
            } catch {
                skipped += 1
            }
        }

        reload()
        if let last {
            if folder.fileKey != rootURL?.fileKey {
                expanded.insert(folder.fileKey)
            }
            expandAncestors(of: last)
            selection = last.fileKey
        }
        return (imported, skipped)
    }

    func trash(_ url: URL) throws {
        try fileManager.trashItem(at: url, resultingItemURL: nil)
        let key = url.fileKey
        if let selection, selection == key || selection.hasPrefix(key + "/") {
            self.selection = nil
        }
        reload()
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Updates selection, open folders and tabs after an item moves.
    private func remapKeys(from oldKey: String, to newKey: String) {
        func remap(_ key: String) -> String {
            if key == oldKey { return newKey }
            if key.hasPrefix(oldKey + "/") { return newKey + key.dropFirst(oldKey.count) }
            return key
        }
        expanded = Set(expanded.map(remap))
        selection = selection.map(remap)
        tabs = tabs.map(remap)
        activeTab = activeTab.map(remap)
        saveTabs()
    }

    private func uniqueURL(named base: String, pathExtension: String?, in folder: URL) -> URL {
        var number = 1
        while true {
            let name = number == 1 ? base : "\(base) \(number)"
            var url = folder.appendingPathComponent(name, isDirectory: pathExtension == nil)
            if let pathExtension {
                url = url.appendingPathExtension(pathExtension)
            }
            if !fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                return url
            }
            number += 1
        }
    }
}