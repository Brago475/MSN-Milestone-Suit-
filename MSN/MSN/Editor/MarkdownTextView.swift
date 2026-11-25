import AppKit
import SwiftUI

/// Native text view for editing Markdown with live styling.
struct MarkdownTextView: NSViewRepresentable {

    let document: MarkdownDocument
    let controller: EditorController
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, controller: controller, fontSize: fontSize)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 40, height: 28)
        textView.backgroundColor = .textBackgroundColor

        textView.string = document.text
        restyle(textView)
        controller.textView = textView
        controller.updateCurrentStyle()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        controller.textView = textView
        context.coordinator.document = document

        if context.coordinator.fontSize != fontSize {
            context.coordinator.fontSize = fontSize
            restyle(textView)
        }

        // Text replaced from disk while open.
        if textView.string != document.text && !textView.hasMarkedText() {
            let selection = textView.selectedRange()
            textView.string = document.text
            restyle(textView)
            let length = (document.text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
    }

    private func restyle(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        MarkdownStyle.apply(to: storage, baseSize: fontSize)
        textView.typingAttributes = MarkdownStyle.baseAttributes(size: fontSize)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: MarkdownDocument
        let controller: EditorController
        var fontSize: CGFloat

        init(document: MarkdownDocument, controller: EditorController, fontSize: CGFloat) {
            self.document = document
            self.controller = controller
            self.fontSize = fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if !textView.hasMarkedText(), let storage = textView.textStorage {
                MarkdownStyle.apply(to: storage, baseSize: fontSize)
            }
            document.update(textView.string)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller.updateCurrentStyle()
        }
    }
}