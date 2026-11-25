import AppKit
import Observation

/// Formatting commands and typing rules for Page view.
@MainActor
@Observable
final class PageController: EditorCommands {

    @ObservationIgnored weak var textView: PageTextView?

    private(set) var currentStyle: TextStyle = .normal
    private(set) var currentFont: PageFont = .system
    private(set) var currentSize: Double = 11
    private(set) var currentAlignment: PageAlignment = .left
    private(set) var currentSpacing: Double = PageStyle.defaultSpacing

    var isRichText: Bool { true }

    private static let inlineKeys: [NSAttributedString.Key] = [
        .msnBold, .msnItalic, .msnUnderline, .msnStrike, .msnCode,
        .msnFont, .msnSize, .msnColor, .msnHighlight
    ]

    // MARK: History

    func undo() {
        textView?.undoManager?.undo()
    }

    func redo() {
        textView?.undoManager?.redo()
    }

    // MARK: Inline

    func toggleBold() { toggleInline(.msnBold) }
    func toggleItalic() { toggleInline(.msnItalic) }
    func toggleUnderline() { toggleInline(.msnUnderline) }
    func toggleStrike() { toggleInline(.msnStrike) }

    func setFont(_ font: PageFont) {
        applyInline(.msnFont, font.rawValue)
    }

    func setSize(_ size: Double) {
        applyInline(.msnSize, min(96, max(6, size)))
    }

    func stepSize(_ delta: Double) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        guard selection.length > 0 else {
            setSize(currentSize + delta)
            return
        }
        edit(selection) { storage in
            var runs: [(NSRange, Double)] = []
            storage.enumerateAttributes(in: selection) { attributes, range, _ in
                let base = attributes[.msnSize] as? Double ?? PageStyle.defaultSize(PageBlock(attributes))
                runs.append((range, min(96, max(6, base + delta))))
            }
            for (range, size) in runs {
                storage.addAttribute(.msnSize, value: size, range: range)
            }
        }
        updateState()
    }

    func setTextColor(_ hex: String?) {
        applyInline(.msnColor, hex)
    }

    func setHighlight(_ hex: String?) {
        applyInline(.msnHighlight, hex)
    }

    func clearFormatting() {
        guard let textView, let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()

        if selection.length == 0 {
            let block = PageBlock(textView.typingAttributes)
            let level = textView.typingAttributes[.msnLevel] as? Int ?? 0
            textView.typingAttributes = PageStyle.typingAttributes(block: block, level: level)
            updateState()
            return
        }

        let paragraphs = selectedParagraphs().filter { $0.length > 0 }
        let union = paragraphs.reduce(selection) { NSUnionRange($0, $1) }
        guard textView.shouldChangeText(in: union, replacementString: nil) else { return }
        for key in Self.inlineKeys {
            storage.removeAttribute(key, range: selection)
        }
        for paragraph in paragraphs {
            for key in [NSAttributedString.Key.msnAlign, .msnSpacing, .msnIndent] {
                storage.removeAttribute(key, range: paragraph)
            }
        }
        PageStyle.restyle(storage, around: union)
        textView.didChangeText()
        updateState()
        focus()
    }

    func insertLink() {
        guard let textView, let storage = textView.textStorage else { return }
        let alert = NSAlert()
        alert.messageText = "Add link"
        alert.informativeText = "Enter the web address."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let address = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !address.isEmpty else { return }

        let selection = textView.selectedRange()
        if selection.length > 0 {
            edit(selection) { storage in
                storage.addAttribute(.link, value: address, range: selection)
            }
        } else {
            var attributes = textView.typingAttributes
            attributes[.link] = address
            let inserted = NSAttributedString(string: address, attributes: attributes)
            guard textView.shouldChangeText(in: selection, replacementString: address) else { return }
            storage.replaceCharacters(in: selection, with: inserted)
            PageStyle.restyle(storage, around: NSRange(location: selection.location, length: inserted.length))
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: selection.location + inserted.length, length: 0))
        }
    }

    private func toggleInline(_ key: NSAttributedString.Key) {
        guard let textView, let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()

        if selection.length == 0 {
            let has = textView.typingAttributes[key] != nil
            applyInline(key, has ? nil : true)
            return
        }

        var allHave = true
        storage.enumerateAttribute(key, in: selection) { value, _, stop in
            if value == nil {
                allHave = false
                stop.pointee = true
            }
        }
        applyInline(key, allHave ? nil : true)
    }

    /// Sets or clears an inline value on the selection, or on what is typed next.
    private func applyInline(_ key: NSAttributedString.Key, _ value: Any?) {
        guard let textView else { return }
        let selection = textView.selectedRange()

        if selection.length == 0 {
            var semantic = textView.typingAttributes
            semantic[key] = value
            textView.typingAttributes = PageStyle.typingAttributes(
                block: PageBlock(semantic),
                level: semantic[.msnLevel] as? Int ?? 0,
                props: ParagraphProps(semantic),
                semantic: semantic
            )
            updateState()
            return
        }

        edit(selection) { storage in
            if let value {
                storage.addAttribute(key, value: value, range: selection)
            } else {
                storage.removeAttribute(key, range: selection)
            }
        }
        updateState()
    }

    // MARK: Paragraphs

    func setAlignment(_ alignment: PageAlignment) {
        applyParagraph { $0.align = alignment }
    }

    func setLineSpacing(_ spacing: Double) {
        applyParagraph { $0.spacing = spacing }
    }

    func indent(_ delta: Int) {
        guard let textView else { return }
        let current = info(at: textView.selectedRange().location)
        if current.block.isList {
            applyBlock(current.block, level: max(0, min(6, current.level + delta)), to: selectedParagraphs())
        } else {
            applyParagraph { $0.indent = max(0, min(8, $0.indent + delta)) }
        }
    }

    /// Changes paragraph settings for every selected paragraph with undo support.
    private func applyParagraph(_ change: (inout ParagraphProps) -> Void) {
        guard let textView, let storage = textView.textStorage else { return }
        let paragraphs = selectedParagraphs().filter { $0.length > 0 }

        if paragraphs.isEmpty {
            var semantic = textView.typingAttributes
            var props = ParagraphProps(semantic)
            change(&props)
            props.apply(to: &semantic)
            textView.typingAttributes = PageStyle.typingAttributes(
                block: PageBlock(semantic),
                level: semantic[.msnLevel] as? Int ?? 0,
                props: props,
                semantic: semantic
            )
            updateState()
            return
        }

        let union = paragraphs.dropFirst().reduce(paragraphs[0]) { NSUnionRange($0, $1) }
        guard textView.shouldChangeText(in: union, replacementString: nil) else { return }
        for paragraph in paragraphs {
            var props = ParagraphProps(storage.attributes(at: paragraph.location, effectiveRange: nil))
            change(&props)
            var values: [NSAttributedString.Key: Any] = [:]
            props.apply(to: &values)
            for key in [NSAttributedString.Key.msnAlign, .msnSpacing, .msnIndent] {
                if let value = values[key] {
                    storage.addAttribute(key, value: value, range: paragraph)
                } else {
                    storage.removeAttribute(key, range: paragraph)
                }
            }
        }
        PageStyle.restyle(storage, around: union)
        textView.didChangeText()
        textView.needsDisplay = true
        updateState()
        focus()
    }

    // MARK: Blocks

    func setStyle(_ style: TextStyle) {
        let block: PageBlock
        switch style {
        case .normal: block = .normal
        case .title: block = .title
        case .heading1: block = .heading1
        case .heading2: block = .heading2
        case .heading3: block = .heading3
        case .quote: block = .quote
        }
        applyBlock(block, level: 0, to: selectedParagraphs())
        updateState()
    }

    func toggleList(_ kind: ListKind) {
        let target: PageBlock
        switch kind {
        case .bullet: target = .bullet
        case .numbered: target = .ordered
        case .checklist: target = .task
        }
        let paragraphs = selectedParagraphs()
        let allSame = paragraphs.allSatisfy {
            let block = info(at: $0.location).block
            return block == target || (target == .task && block == .taskDone)
        }
        applyBlock(allSame ? .normal : target, level: allSame ? 0 : nil, to: paragraphs)
        updateState()
    }

    /// Turns the selected paragraphs into a code block, or back into text.
    func insertCodeBlock() {
        let paragraphs = selectedParagraphs()
        let allCode = paragraphs.allSatisfy { info(at: $0.location).block == .code }
        if allCode {
            applyBlock(.normal, level: 0, to: paragraphs)
        } else {
            applyBlock(.code, level: 0, to: paragraphs, id: UUID().uuidString)
        }
        updateState()
    }

    func insertTable() {
        guard let textView, let storage = textView.textStorage else { return }
        let ns = storage.string as NSString
        let caret = textView.selectedRange().location
        let paragraph = ns.paragraphRange(for: NSRange(location: caret, length: 0))
        let paragraphText = ns.substring(with: paragraph)
        let content = paragraphText.trimmingCharacters(in: .newlines)
        let endsWithNewline = paragraphText.hasSuffix("\n")

        let table = "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |"
        let prefix = content.isEmpty ? "" : "\n"
        let insertAt = content.isEmpty ? paragraph.location : NSMaxRange(paragraph) - (endsWithNewline ? 1 : 0)
        let replaceLength = content.isEmpty ? paragraph.length - (endsWithNewline ? 1 : 0) : 0
        let attributes = PageStyle.typingAttributes(block: .raw, semantic: [.msnBlockID: UUID().uuidString])
        let inserted = NSAttributedString(string: prefix + table, attributes: attributes)
        let range = NSRange(location: insertAt, length: replaceLength)

        guard textView.shouldChangeText(in: range, replacementString: inserted.string) else { return }
        storage.replaceCharacters(in: range, with: inserted)
        PageStyle.restyle(storage, around: NSRange(location: insertAt, length: inserted.length))
        textView.didChangeText()
        focus()
    }

    func toggleTask(paragraph: NSRange) {
        let current = info(at: paragraph.location)
        let next: PageBlock = current.block == .taskDone ? .task : .taskDone
        applyBlock(next, level: current.level, to: [paragraph])
    }

    // MARK: Typing rules

    /// Handles Enter, Backspace and Tab inside lists, headings, quotes and code.
    func handle(_ selector: Selector) -> Bool {
        guard let textView, let storage = textView.textStorage else { return false }
        let ns = storage.string as NSString
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }

        let paragraph = ns.paragraphRange(for: NSRange(location: selection.location, length: 0))
        let current = info(at: paragraph.location)
        let content = ns.substring(with: paragraph).trimmingCharacters(in: .newlines)
        let contentEnd = paragraph.location + (content as NSString).length

        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if content.isEmpty && (current.block.isList || current.block == .quote || current.block == .code) {
                applyBlock(.normal, level: 0, to: [paragraph])
                return true
            }
            if current.block.isHeading && selection.location == contentEnd {
                textView.insertNewline(nil)
                resetNewParagraph(to: .normal, level: 0)
                return true
            }
            if current.block == .taskDone {
                textView.insertNewline(nil)
                resetNewParagraph(to: .task, level: current.level)
                return true
            }
            return false

        case #selector(NSResponder.deleteBackward(_:)):
            guard selection.location == paragraph.location, current.block != .normal else { return false }
            if current.block.isList && current.level > 0 {
                applyBlock(current.block, level: current.level - 1, to: [paragraph])
            } else {
                applyBlock(.normal, level: 0, to: [paragraph])
            }
            return true

        case #selector(NSResponder.insertTab(_:)):
            guard current.block.isList else { return false }
            applyBlock(current.block, level: min(current.level + 1, 6), to: selectedParagraphs())
            return true

        case #selector(NSResponder.insertBacktab(_:)):
            guard current.block.isList, current.level > 0 else { return current.block.isList }
            applyBlock(current.block, level: current.level - 1, to: selectedParagraphs())
            return true

        default:
            return false
        }
    }

    private func resetNewParagraph(to block: PageBlock, level: Int) {
        guard let textView, let storage = textView.textStorage else { return }
        let ns = storage.string as NSString
        let caret = textView.selectedRange().location
        let paragraph = ns.paragraphRange(for: NSRange(location: caret, length: 0))
        if paragraph.length > 0 {
            storage.addAttribute(.msnBlock, value: block.rawValue, range: paragraph)
            storage.addAttribute(.msnLevel, value: level, range: paragraph)
            PageStyle.restyle(storage, around: paragraph)
        }
        textView.typingAttributes = PageStyle.typingAttributes(block: block, level: level)
        updateState()
    }

    // MARK: State

    /// Reads style, font, size and alignment at the cursor for the toolbar.
    func updateState() {
        guard let textView, let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let attributes: [NSAttributedString.Key: Any]
        if selection.length > 0, selection.location < storage.length {
            attributes = storage.attributes(at: selection.location, effectiveRange: nil)
        } else {
            attributes = textView.typingAttributes
        }

        let block = PageBlock(attributes)
        switch block {
        case .title: currentStyle = .title
        case .heading1: currentStyle = .heading1
        case .heading2: currentStyle = .heading2
        case .heading3: currentStyle = .heading3
        case .quote: currentStyle = .quote
        default: currentStyle = .normal
        }
        currentFont = PageFont(rawValue: attributes[.msnFont] as? String ?? "") ?? PageStyle.defaultFont(block)
        currentSize = attributes[.msnSize] as? Double ?? PageStyle.defaultSize(block)
        let props = ParagraphProps(attributes)
        currentAlignment = props.align
        currentSpacing = props.spacing
    }

    // MARK: Helpers

    private func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    private func info(at location: Int) -> (block: PageBlock, level: Int) {
        guard let textView, let storage = textView.textStorage else { return (.normal, 0) }
        let attributes: [NSAttributedString.Key: Any]
        if location < storage.length {
            attributes = storage.attributes(at: location, effectiveRange: nil)
        } else if storage.length > 0, location == storage.length,
                  (storage.string as NSString).character(at: storage.length - 1) != 10 {
            attributes = storage.attributes(at: storage.length - 1, effectiveRange: nil)
        } else {
            attributes = textView.typingAttributes
        }
        return (PageBlock(attributes), attributes[.msnLevel] as? Int ?? 0)
    }

    private func selectedParagraphs() -> [NSRange] {
        guard let textView, let storage = textView.textStorage else { return [] }
        let ns = storage.string as NSString
        let target = ns.paragraphRange(for: textView.selectedRange())
        var paragraphs: [NSRange] = []
        ns.enumerateSubstrings(in: target, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
            paragraphs.append(enclosing)
        }
        if paragraphs.isEmpty {
            paragraphs = [NSRange(location: ns.length, length: 0)]
        }
        return paragraphs
    }

    /// Sets the block kind of paragraphs with undo support.
    private func applyBlock(_ block: PageBlock, level: Int?, to paragraphs: [NSRange], id: String? = nil) {
        guard let textView, let storage = textView.textStorage else { return }
        let filled = paragraphs.filter { $0.length > 0 }

        if filled.isEmpty {
            let current = info(at: textView.selectedRange().location)
            var semantic: [NSAttributedString.Key: Any] = [:]
            if let id { semantic[.msnBlockID] = id }
            textView.typingAttributes = PageStyle.typingAttributes(block: block, level: level ?? current.level, semantic: semantic)
            updateState()
            return
        }

        let union = filled.dropFirst().reduce(filled[0]) { NSUnionRange($0, $1) }
        guard textView.shouldChangeText(in: union, replacementString: nil) else { return }
        for paragraph in filled {
            let currentLevel = storage.attribute(.msnLevel, at: paragraph.location, effectiveRange: nil) as? Int ?? 0
            storage.addAttribute(.msnBlock, value: block.rawValue, range: paragraph)
            storage.addAttribute(.msnLevel, value: block.isList ? (level ?? currentLevel) : 0, range: paragraph)
            if let id {
                storage.addAttribute(.msnBlockID, value: id, range: paragraph)
            } else if !block.isLiteral {
                storage.removeAttribute(.msnBlockID, range: paragraph)
            }
        }
        PageStyle.restyle(storage, around: union)
        textView.didChangeText()
        textView.needsDisplay = true
        focus()
    }

    private func edit(_ range: NSRange, _ change: (NSTextStorage) -> Void) {
        guard let textView, let storage = textView.textStorage,
              textView.shouldChangeText(in: range, replacementString: nil) else { return }
        change(storage)
        PageStyle.restyle(storage, around: range)
        textView.didChangeText()
        focus()
    }
}