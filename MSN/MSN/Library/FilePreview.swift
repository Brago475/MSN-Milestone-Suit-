import PDFKit
import SwiftUI

/// Read-only view of the selected file. Replaced by the editor in the next phase.
struct FilePreview: View {

    @Environment(LibraryStore.self) private var library
    let node: FileNode?

    @State private var text = ""

    var body: some View {
        if let node {
            if node.isFolder {
                ContentUnavailableView(
                    node.name,
                    systemImage: "folder",
                    description: Text("\(node.fileCount) files")
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.name)
                            .font(.system(size: 20, weight: .bold))
                        Text(library.relativePath(of: node.url))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 14)

                    Divider()

                    if node.kind == .pdf {
                        PDFPreview(url: node.url)
                    } else {
                        ScrollView {
                            Text(text.isEmpty ? "This file is empty." : text)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(text.isEmpty ? Color.secondary : Color.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(32)
                        }
                    }
                }
                .task(id: node) {
                    text = (try? String(contentsOf: node.url, encoding: .utf8))
                        ?? "This file could not be read as text."
                }
            }
        } else {
            ContentUnavailableView(
                "No file selected",
                systemImage: "doc.text",
                description: Text("Choose a file in the sidebar, or create one with the new file button.")
            )
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