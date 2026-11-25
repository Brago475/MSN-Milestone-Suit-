import AppKit
import SwiftUI

/// Page view editor: Markdown in, formatted pages on screen, Markdown out.
struct PageEditor: NSViewRepresentable {

    let document: MarkdownDocument
    let controller: PageController
    let zoom: Double
    let pageLayout: PageLayout
    var onPageCount: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, controller: controller)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = PageStyle.surround
        scrollView.allowsMagnification = true
        scrollView.postsFrameChangedNotifications = true

        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: pageLayout.contentWidth, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let textView = PageTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize), textContainer: container)
        layoutManager.delegate = textView
        textView.pageLayout = pageLayout
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.insertionPointColor = .black
        textView.selectedTextAttributes = [.backgroundColor: PageStyle.selection]
        textView.linkTextAttributes = [
            .foregroundColor: PageStyle.accent,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        textView.delegate = context.coordinator
        textView.onToggleTask = { [weak controller] range in
            controller?.toggleTask(paragraph: range)
        }
        textView.onPageCount = onPageCount
        textView.updateInsets()

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.zoom = zoom
        context.coordinator.load(document.text, into: textView)
        controller.textView = textView
        controller.updateState()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.frameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        DispatchQueue.main.async {
            context.coordinator.applyZoom()
        }

        #if DEBUG
        let once = MarkdownWriter.write(MarkdownReader.read(document.text))
        let twice = MarkdownWriter.write(MarkdownReader.read(once))
        if once != twice {
            print("Page round trip is not stable for \(document.fileName)")
        }
        #endif

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PageTextView else { return }
        controller.textView = textView
        textView.onPageCount = onPageCount
        context.coordinator.document = document

        if textView.pageLayout != pageLayout {
            textView.pageLayout = pageLayout
            context.coordinator.applyZoom()
        }
        if context.coordinator.zoom != zoom {
            context.coordinator.zoom = zoom
            context.coordinator.applyZoom()
        }

        // File changed on disk or in Markdown mode.
        if document.text != context.coordinator.lastMarkdown && !textView.hasMarkedText() {
            context.coordinator.load(document.text, into: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: MarkdownDocument
        let controller: PageController
        weak var scrollView: NSScrollView?
        var zoom: Double = 1
        var frontMatter: String?
        var lastMarkdown = ""

        init(document: MarkdownDocument, controller: PageController) {
            self.document = document
            self.controller = controller
        }

        func load(_ markdown: String, into textView: PageTextView) {
            let result = MarkdownReader.read(markdown)
            frontMatter = result.frontMatter
            lastMarkdown = markdown
            guard let storage = textView.textStorage else { return }
            storage.setAttributedString(result.body)
            PageStyle.restyleAll(storage)
            textView.typingAttributes = PageStyle.typingAttributes(block: .normal)
            textView.undoManager?.removeAllActions()
            textView.updatePageCount()
            textView.needsDisplay = true
        }

        /// Uses the chosen zoom, shrunk only as much as needed to keep the page fully visible.
        func applyZoom() {
            guard let scrollView, let textView = scrollView.documentView as? PageTextView else { return }
            let fit = (scrollView.frame.width - 40) / textView.pageLayout.width
            let cap = max(0.25, min(3, fit))
            scrollView.minMagnification = min(0.25, cap)
            scrollView.maxMagnification = cap
            let target = min(CGFloat(zoom), cap)
            if abs(scrollView.magnification - target) > 0.001 {
                scrollView.magnification = target
            }
        }

        @objc func frameChanged(_ notification: Notification) {
            applyZoom()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PageTextView,
                  let storage = textView.textStorage else { return }
            if !textView.hasMarkedText() {
                PageStyle.restyle(storage, around: textView.selectedRange())
            }
            let markdown = MarkdownWriter.write(storage, frontMatter: frontMatter)
            lastMarkdown = markdown
            document.update(markdown)
            textView.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller.updateState()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            controller.handle(commandSelector)
        }
    }
}