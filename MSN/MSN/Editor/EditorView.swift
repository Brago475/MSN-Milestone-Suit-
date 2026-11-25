import AppKit
import Combine
import SwiftUI

/// Editor for a Markdown or text file: header, toolbar, text, status bar.
struct EditorView: View {

    @Environment(LibraryStore.self) private var library
    let node: FileNode

    @State private var document: MarkdownDocument?
    @State private var controller = EditorController()
    @AppStorage("editorFontSize") private var fontSize = 13.0
    @AppStorage("editorMode") private var mode: EditorMode = .markdown

    private var folderPath: String {
        let parent = node.url.deletingLastPathComponent()
        if parent.fileKey == library.rootURL?.fileKey {
            return library.libraryName
        }
        return library.relativePath(of: parent).replacingOccurrences(of: "/", with: " / ")
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorHeader(title: node.name, path: folderPath, mode: $mode)
            Divider()

            if mode == .markdown {
                EditorToolbar(controller: controller, fontSize: $fontSize)
                Divider()
            }

            Group {
                if let document {
                    if mode == .markdown {
                        MarkdownTextView(document: document, controller: controller, fontSize: CGFloat(fontSize))
                            .id(document.url)
                    } else {
                        ContentUnavailableView(
                            "Page view is coming next",
                            systemImage: "doc.richtext",
                            description: Text("Switch to Markdown to edit this file. Page view arrives in step E2.")
                        )
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let document {
                Divider()
                EditorStatusBar(document: document)
            }
        }
        .task(id: node.id) {
            document?.saveNow()
            document = MarkdownDocument(url: node.url)
        }
        .onDisappear {
            document?.saveNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            document?.saveNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            document?.reloadIfChangedOnDisk()
        }
    }
}