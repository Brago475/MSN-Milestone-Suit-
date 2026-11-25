import PDFKit
import SwiftUI

/// Right pane of Files: welcome screen, editor for text files, viewer for PDFs, summary for folders.
struct FilePreview: View {

    @Environment(LibraryStore.self) private var library
    let node: FileNode?

    var body: some View {
        if let node {
            switch node.kind {
            case .folder:
                ContentUnavailableView(
                    node.name,
                    systemImage: "folder",
                    description: Text("\(node.fileCount) files")
                )
            case .markdown, .text:
                EditorView(node: node)
            case .pdf:
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(node.name)
                            .font(.system(size: 14, weight: .semibold))
                        Text(library.relativePath(of: node.url))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    Divider()
                    PDFPreview(url: node.url)
                }
            }
        } else {
            WelcomeView()
        }
    }
}

/// Shows a PDF with PDFKit.
struct PDFPreview: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}