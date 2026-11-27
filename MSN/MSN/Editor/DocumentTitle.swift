import SwiftUI

/// Breadcrumb above the paper: each folder level, then the file name.
/// Folder steps open that folder in Files.
struct DocumentTitle: View {

    @Environment(LibraryStore.self) private var library
    @AppStorage("filesPanelVisible") private var panelVisible = true

    let node: FileNode

    private struct Crumb: Identifiable {
        let id: String
        let title: String
        let url: URL?
    }

    /// Folder levels from the vault down to the file's folder. Files at the top show the vault.
    private var crumbs: [Crumb] {
        guard let root = library.rootURL else { return [] }
        let folder = node.url.deletingLastPathComponent()
        if folder.fileKey == root.fileKey {
            return [Crumb(id: root.fileKey, title: library.libraryName, url: nil)]
        }
        var url = root
        return library.relativePath(of: folder)
            .split(separator: "/")
            .map { part in
                url = url.appendingPathComponent(String(part), isDirectory: true)
                return Crumb(id: url.fileKey, title: String(part), url: url)
            }
    }

    var body: some View {
        let items = crumbs

        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, crumb in
                CrumbButton(
                    title: crumb.title,
                    symbol: index == 0 ? (crumb.url == nil ? "archivebox.fill" : "folder.fill") : nil
                ) {
                    if let url = crumb.url { show(url) }
                }
                .disabled(crumb.url == nil)
                separator
            }

            HStack(spacing: 6) {
                Image(systemName: node.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
                Text(node.name)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.leading, 4)
        }
    }

    private var separator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 2)
    }

    /// Opens Files and selects the folder in the tree.
    private func show(_ folder: URL) {
        withAnimation(.easeInOut(duration: 0.2)) {
            panelVisible = true
        }
        library.expandAncestors(of: folder)
        library.expanded.insert(folder.fileKey)
        library.selection = folder.fileKey
    }
}

/// One folder step. Quiet until hovered.
private struct CrumbButton: View {

    let title: String
    let symbol: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(
                Color.primary.opacity(isHovered ? 0.07 : 0),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Show \(title) in Files")
    }
}