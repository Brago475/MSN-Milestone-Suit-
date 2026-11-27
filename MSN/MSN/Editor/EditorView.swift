import AppKit
import Combine
import SwiftUI

/// Editor for a Markdown or text file: toolbar, name above the paper, pages or Markdown, dock, status bar.
struct EditorView: View {

    @Environment(LibraryStore.self) private var library
    @Environment(\.menuBarInset) private var menuBarInset
    let node: FileNode

    @State private var document: MarkdownDocument?
    @State private var markdownController = EditorController()
    @State private var pageController = PageController()
    @State private var pageCount = 1
    @State private var areaWidth: CGFloat = 0
    @State private var isScrolled = false
    @AppStorage("editorFontSize") private var fontSize = 13.0
    @AppStorage("editorViewMode") private var mode: EditorMode = .page
    @AppStorage("pageZoomLevel") private var zoom = 1.0
    @AppStorage("pagePaper") private var paper: PaperSize = .letter
    @AppStorage("pageMargins") private var margins: MarginPreset = .normal

    private var commands: any EditorCommands {
        mode == .page ? pageController : markdownController
    }

    private var pageLayout: PageLayout {
        PageLayout(paper: paper, margins: margins)
    }

    /// Paper width on screen, matching the page editor's zoom and fit rule.
    private var paperWidth: CGFloat {
        let page = pageLayout.width
        guard areaWidth > 0, page > 0 else { return 0 }
        let fit = (areaWidth - 40) / page
        let scale = min(CGFloat(zoom), max(0.25, min(3, fit)))
        return page * scale
    }

    /// The dock shows only in Page view, when the space beside the paper can hold it.
    private var showsDock: Bool {
        guard mode == .page, areaWidth > 0 else { return false }
        return (areaWidth - paperWidth) / 2 >= DocumentDock.width + DocumentDock.margin * 2
    }

    /// The line under the name row: after scrolling, or while the menu bar pushes the top down.
    private var showsEdge: Bool {
        mode == .page && (isScrolled || menuBarInset > 0)
    }

    private var surround: Color {
        mode == .page ? Color(nsColor: PageStyle.surround) : Color(nsColor: .textBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                EditorToolbar(
                    commands: commands,
                    markdownSize: $fontSize,
                    zoom: $zoom,
                    paper: $paper,
                    margins: $margins,
                    mode: $mode,
                    showsActions: !showsDock
                )
                Divider()
            }
            .background(Theme.surface)
            .offset(y: menuBarInset)
            .zIndex(3)

            VStack(spacing: 0) {
                titleRow
                    .offset(y: menuBarInset)
                    .zIndex(2)
                editorArea
                    .overlay(alignment: .topTrailing) {
                        if showsDock {
                            DocumentDock(mode: $mode)
                                .padding(.top, 12)
                                .padding(.trailing, DocumentDock.margin)
                                .offset(y: menuBarInset)
                                .transition(.opacity)
                        }
                    }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                areaWidth = width
            }
            .animation(.easeOut(duration: 0.15), value: showsDock)

            if let document {
                Divider()
                EditorStatusBar(document: document, mode: mode, pageCount: pageCount)
            }
        }
        .task(id: node.id) {
            document?.saveNow()
            isScrolled = false
            document = MarkdownDocument(url: node.url)
        }
        .onChange(of: mode) { _, _ in
            isScrolled = false
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

    // MARK: Parts

    /// Lined up with the paper in Page view, with the text in Markdown mode.
    /// Its height never changes, so the page below never resizes; only the line and shadow fade.
    @ViewBuilder
    private var titleRow: some View {
        Group {
            if mode == .page {
                DocumentTitle(node: node)
                    .frame(width: max(0, paperWidth), alignment: .leading)
                    .frame(maxWidth: .infinity)
            } else {
                DocumentTitle(node: node)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(surround)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.tabOutline)
                .frame(height: 1)
                .opacity(showsEdge ? 1 : 0)
        }
        .shadow(color: .black.opacity(showsEdge ? 0.07 : 0), radius: 4, y: 2)
        .animation(.easeOut(duration: 0.15), value: showsEdge)
    }

    @ViewBuilder
    private var editorArea: some View {
        Group {
            if let document {
                switch mode {
                case .page:
                    PageEditor(
                        document: document,
                        controller: pageController,
                        zoom: zoom,
                        pageLayout: pageLayout,
                        onPageCount: { pageCount = $0 },
                        onScroll: { isScrolled = $0 }
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
    }
}