import AppKit
import Combine
import SwiftUI

/// Editor for a Markdown or text file: header, toolbar, pages or Markdown, status bar.
struct EditorView: View {

    @Environment(LibraryStore.self) private var library
    let node: FileNode

    @State private var document: MarkdownDocument?
    @State private var markdownController = EditorController()
    @State private var pageController = PageController()
    @State private var pageCount = 1
    @AppStorage("editorFontSize") private var fontSize = 13.0
    @AppStorage("editorViewMode") private var mode: EditorMode = .page
    @AppStorage("pageZoomLevel") private var zoom = 1.0
    @AppStorage("pagePaper") private var paper: PaperSize = .letter
    @AppStorage("pageMargins") private var margins: MarginPreset = .normal

    private var folderPath: String {
        let parent = node.url.deletingLastPathComponent()
        if parent.fileKey == library.rootURL?.fileKey {
            return library.libraryName
        }
        return library.relativePath(of: parent).replacingOccurrences(of: "/", with: " / ")
    }

    private var commands: any EditorCommands {
        mode == .page ? pageController : markdownController
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorHeader(title: node.name, path: folderPath, mode: $mode)
            Divider()

            EditorToolbar(
                commands: commands,
                markdownSize: $fontSize,
                zoom: $zoom,
                paper: $paper,
                margins: $margins
            )
            Divider()

            Group {
                if let document {
                    switch mode {
                    case .page:
                        PageEditor(
                            document: document,
                            controller: pageController,
                            zoom: zoom,
                            pageLayout: PageLayout(paper: paper, margins: margins),
                            onPageCount: { pageCount = $0 }
                        )
                        .id(document.url)
                    case .markdown:
                        MarkdownTextView(document: document, controller: markdownController, fontSize: CGFloat(fontSize))
                            .id(document.url)
                    }
                } else {
                    DelayedView {
                        EditorSkeleton()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let document {
                Divider()
                EditorStatusBar(document: document, mode: mode, pageCount: pageCount)
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