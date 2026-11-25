import Foundation

/// One item in the library tree.
struct FileNode: Identifiable, Hashable {

    enum Kind: Hashable {
        case folder
        case markdown
        case text
        case pdf
    }

    let url: URL
    let kind: Kind
    var children: [FileNode]
    let modified: Date

    var id: String { url.fileKey }
    var isFolder: Bool { kind == .folder }

    /// Display name. Files hide their extension.
    var name: String {
        isFolder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
    }

    var symbol: String {
        switch kind {
        case .folder: "folder"
        case .markdown: "doc.text"
        case .text: "doc.plaintext"
        case .pdf: "doc.richtext"
        }
    }

    /// Number of files inside this folder, counted through all subfolders.
    var fileCount: Int {
        guard isFolder else { return 1 }
        return children.reduce(0) { $0 + ($1.isFolder ? $1.fileCount : 1) }
    }

    /// File types shown in the library. Others are skipped.
    static func kind(for url: URL) -> Kind? {
        switch url.pathExtension.lowercased() {
        case "md", "markdown": .markdown
        case "txt": .text
        case "pdf": .pdf
        default: nil
        }
    }
}

/// A visible row in the tree.
struct TreeRow: Identifiable {
    let node: FileNode
    let depth: Int
    var id: String { node.id }
}

extension URL {
    /// Stable path used to compare files and folders.
    var fileKey: String {
        var path = standardizedFileURL.path(percentEncoded: false)
        if path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}