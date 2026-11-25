import SwiftUI

/// The Files sidebar: header actions, search, and the folder tree.
struct FilesSidebar: View {

    @Environment(LibraryStore.self) private var library

    @State private var query = ""
    @State private var matches: Set<String>?
    @State private var renameURL: URL?
    @State private var renameText = ""
    @State private var showRename = false
    @State private var trashURL: URL?
    @FocusState private var searchFocused: Bool

    private var rows: [TreeRow] {
        library.visibleRows(matching: matches)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            tree
        }
        .frame(maxHeight: .infinity)
        .background(.background)
        .task(id: query) {
            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                matches = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            matches = library.matches(for: query)
        }
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(get: { trashURL != nil }, set: { if !$0 { trashURL = nil } }),
            presenting: trashURL
        ) { url in
            Button("Move to Trash", role: .destructive) {
                perform { try library.trash(url) }
            }
        } message: { url in
            Text("\"\(url.lastPathComponent)\" will be moved to the Trash. You can restore it from there.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { library.lastError != nil }, set: { if !$0 { library.lastError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(library.lastError ?? "")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 2) {
            Text("Files")
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            headerButton("doc.badge.plus", "New file") { newFile(in: nil) }
                .keyboardShortcut("n", modifiers: .command)
            headerButton("folder.badge.plus", "New folder") { newFolder(in: nil) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            headerButton("pencil", "Rename") {
                if let node = library.selectedNode { beginRename(node.url) }
            }
            .disabled(library.selectedNode == nil)

            Menu {
                ForEach(LibraryStore.SortOrder.allCases, id: \.self) { order in
                    Button {
                        library.sortOrder = order
                    } label: {
                        if library.sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 26, height: 26)
            .foregroundStyle(.secondary)
            .help("Sort")

            headerButton("rectangle.compress.vertical", "Collapse all") { library.collapseAll() }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 48)
    }

    private func headerButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search files and text", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if query.isEmpty {
                Text("⌘K")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
    }

    // MARK: Tree

    private var tree: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(rows) { row in
                    FileRowView(
                        row: row,
                        isSelected: library.selection == row.node.id,
                        isExpanded: matches != nil || library.expanded.contains(row.node.id)
                    )
                    .onTapGesture { select(row.node) }
                    .contextMenu { menu(for: row.node) }
                }

                if rows.isEmpty {
                    Text(matches == nil ? "This folder is empty. Use the new file button to start." : "No matches.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .contextMenu { menu(for: nil) }
        .onDeleteCommand {
            if let node = library.selectedNode { trashURL = node.url }
        }
    }

    @ViewBuilder
    private func menu(for node: FileNode?) -> some View {
        let folder = node.map { $0.isFolder ? $0.url : $0.url.deletingLastPathComponent() } ?? library.rootURL
        Button("New File") { newFile(in: folder) }
        Button("New Folder") { newFolder(in: folder) }
        if let node {
            Divider()
            Button("Rename…") { beginRename(node.url) }
            Button("Show in Finder") { library.reveal(node.url) }
            Divider()
            Button("Move to Trash", role: .destructive) { trashURL = node.url }
        }
    }

    // MARK: Actions

    private func select(_ node: FileNode) {
        library.selection = node.id
        if node.isFolder {
            library.toggle(node)
        }
    }

    private func newFile(in folder: URL?) {
        perform {
            let url = try library.createNote(in: folder)
            beginRename(url)
        }
    }

    private func newFolder(in folder: URL?) {
        perform {
            let url = try library.createFolder(in: folder)
            beginRename(url)
        }
    }

    private func beginRename(_ url: URL) {
        renameURL = url
        let isFolder = library.index[url.fileKey]?.isFolder ?? false
        renameText = isFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        showRename = true
    }

    private func commitRename() {
        guard let url = renameURL else { return }
        perform { try library.rename(url, to: renameText) }
        renameURL = nil
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            library.lastError = error.localizedDescription
        }
    }
}

/// One row in the tree. Top-level folders show as section headers.
struct FileRowView: View {

    let row: TreeRow
    let isSelected: Bool
    let isExpanded: Bool

    private var node: FileNode { row.node }

    var body: some View {
        if row.depth == 0 && node.isFolder {
            sectionHeader
        } else {
            itemRow
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(node.name.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.66)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(node.fileCount)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            isSelected ? Theme.accent.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(Rectangle())
        .padding(.top, 8)
    }

    private var itemRow: some View {
        let filled = isSelected && !node.isFolder

        return HStack(spacing: 6) {
            if node.isFolder {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            } else {
                Color.clear.frame(width: 12)
            }
            Image(systemName: node.symbol)
                .font(.system(size: 12))
                .foregroundStyle(filled ? Color.white : Color.secondary)
            Text(node.name)
                .font(.system(size: 13, weight: node.isFolder || filled ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .foregroundStyle(filled ? Color.white : Color.primary)
        .padding(.leading, CGFloat(8 + max(0, row.depth - 1) * 18))
        .padding(.trailing, 10)
        .frame(height: 28)
        .background(
            filled ? Theme.accent : (isSelected ? Theme.accent.opacity(0.12) : Color.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(alignment: .leading) {
            ForEach(1..<max(1, row.depth), id: \.self) { level in
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .offset(x: CGFloat(8 + (level - 1) * 18 + 6))
            }
        }
        .contentShape(Rectangle())
    }
}