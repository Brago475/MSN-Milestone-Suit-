import Foundation

/// Open tabs: opening, closing, switching, and saving them for each vault.
extension LibraryStore {

    var activeIndex: Int? {
        activeTab.flatMap { tabs.firstIndex(of: $0) }
    }

    /// Folder for new files from the tab bar: the open file's folder, or the vault's top folder.
    var activeFolder: URL? {
        activeNode?.url.deletingLastPathComponent() ?? rootURL
    }

    // MARK: Open and close

    /// Opens a file in the current tab or a new one. A file already open switches to its tab.
    func openInTab(_ node: FileNode, newTab: Bool = false) {
        guard !node.isFolder else { return }
        if tabs.contains(node.id) {
            activate(node.id)
            return
        }
        if let index = activeIndex {
            if newTab {
                tabs.insert(node.id, at: index + 1)
            } else {
                tabs[index] = node.id
            }
        } else {
            tabs.append(node.id)
        }
        activate(node.id)
    }

    func activate(_ id: String) {
        guard tabs.contains(id) else { return }
        activeTab = id
        selection = id
        if let node = index[id] {
            expandAncestors(of: node.url)
        }
        saveTabs()
    }

    /// Closes a tab. Closing the open tab shows the one to its right, or to its left at the end.
    func closeTab(_ id: String) {
        guard let position = tabs.firstIndex(of: id) else { return }
        tabs.remove(at: position)

        if activeTab == id {
            if tabs.isEmpty {
                activeTab = nil
                if selection == id { selection = nil }
            } else {
                activate(tabs[min(position, tabs.count - 1)])
                return
            }
        }
        saveTabs()
    }

    func closeActiveTab() {
        if let activeTab { closeTab(activeTab) }
    }

    func closeOtherTabs(than id: String) {
        guard tabs.contains(id) else { return }
        tabs = [id]
        activate(id)
    }

    /// Moves to the next or previous tab, wrapping around.
    func cycleTabs(by offset: Int) {
        guard let index = activeIndex, tabs.count > 1 else { return }
        activate(tabs[(index + offset + tabs.count) % tabs.count])
    }

    // MARK: New files

    /// Creates "Untitled" in a folder and opens it in a tab.
    @discardableResult
    func createNoteInTab(in folder: URL? = nil, newTab: Bool) throws -> URL {
        let url = try createNote(in: folder)
        if let node = index[url.fileKey] {
            openInTab(node, newTab: newTab)
        }
        return url
    }

    /// The + button and ⌘T: a new file next to the open one, in a new tab, then asks for a name.
    func newFileInNewTab() {
        guard hasLibrary else { return }
        do {
            renameRequest = try createNoteInTab(in: activeFolder, newTab: true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Keeping tabs valid

    /// Drops tabs whose files are gone, such as after a delete in Finder.
    func pruneTabs() {
        let kept = tabs.filter { index[$0].map { !$0.isFolder } ?? false }
        guard kept != tabs else { return }

        let oldIndex = activeIndex ?? 0
        tabs = kept
        if let activeTab, !kept.contains(activeTab) {
            self.activeTab = kept.isEmpty ? nil : kept[min(oldIndex, kept.count - 1)]
            if let replacement = self.activeTab {
                selection = replacement
            }
        }
        saveTabs()
    }

    // MARK: Saving

    /// Tabs are saved as paths inside the vault, so they still work if the vault folder moves.
    private var tabsDefaultsKey: String? {
        VaultRegistry.currentID.map { "openTabs.\($0)" }
    }

    func saveTabs() {
        guard let key = tabsDefaultsKey, rootURL != nil else { return }
        let defaults = UserDefaults.standard
        defaults.set(tabs.map { relativePath(of: URL(fileURLWithPath: $0)) }, forKey: key)
        defaults.set(activeTab.map { relativePath(of: URL(fileURLWithPath: $0)) }, forKey: key + ".active")
    }

    func restoreTabs() {
        guard let key = tabsDefaultsKey, let rootURL else { return }
        let defaults = UserDefaults.standard

        var seen = Set<String>()
        tabs = (defaults.stringArray(forKey: key) ?? [])
            .map { rootURL.appendingPathComponent($0).fileKey }
            .filter { key in
                guard let node = index[key], !node.isFolder else { return false }
                return seen.insert(key).inserted
            }

        let saved = defaults.string(forKey: key + ".active").map { rootURL.appendingPathComponent($0).fileKey }
        if let saved, tabs.contains(saved) {
            activate(saved)
        } else if let first = tabs.first {
            activate(first)
        } else {
            activeTab = nil
        }
    }
}