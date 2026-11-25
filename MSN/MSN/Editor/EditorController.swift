import AppKit
import Observation

/// Paragraph styles offered in the toolbar.
enum TextStyle: String, CaseIterable, Identifiable {
    case normal = "Normal text"
    case title = "Title"
    case heading1 = "Heading 1"
    case heading2 = "Heading 2"
    case heading3 = "Heading 3"
    case quote = "Quote"

    var id: String { rawValue }

    var prefix: String {
        switch self {
        case .normal: ""
        case .title, .heading1: "# "
        case .heading2: "## "
        case .heading3: "### "
        case .quote: "> "
        }
    }
}

enum ListKind {
    case bullet
    case numbered
    case checklist
}

/// Formatting commands for Markdown mode. Inserts Markdown syntax as text.
@MainActor
@Observable
final class EditorController: EditorCommands {

    @ObservationIgnored weak var textView: NSTextView?
    private(set) var currentStyle: TextStyle = .normal

    var isRichText: Bool { false }
    var currentFont: PageFont { .menlo }
    var currentSize: Double { 0 }
    var currentAlignment: PageAlignment { .left }
    var currentSpacing: Double { PageStyle.defaultSpacing }

    private static let stylePrefix = try! NSRegularExpression(pattern: #"^(#{1,6}[ \t]+|>[ \t]?)"#)
    private static let listPrefix = try! NSRegularExpression(pattern: #"^([ \t]*)([-*+][ \t]\[[ xX]\][ \t]|[-*+][ \t]|\d+\.[ \t])"#)

    // MARK: History

    func undo() {
        textView?.undoManager?.undo()
    }

    func redo() {
        textView?.undoManager?.redo()
    }

    // MARK: Inline

    func toggleBold() { toggleWrap("**", placeholder: "bold text") }
    func toggleItalic() { toggleWrap("*", placeholder: "italic text") }
    func toggleUnderline() { toggleWrap("<u>", "</u>", placeholder: "underlined text") }
    func toggleStrike() { toggleWrap("~~", placeholder: "text") }

    // Rich formatting is only available in Page view.
    func setFont(_ font: PageFont) {}
    func setSize(_ size: Double) {}
    func stepSize(_ delta: Double) {}
    func setTextColor(_ hex: String?) {}
    func setHighlight(_ hex: String?) {}
    func clearFormatting() {}
    func setAlignment(_ alignment: PageAlignment) {}
    func setLineSpacing(_ spacing: Double) {}
    func indent(_ delta: Int) {}

    /// Wraps the selection, or removes the wrap if it is already there.
    func toggleWrap(_ open: String, _ close: String? = nil, placeholder: String) {
        guard let textView else { return }
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let close = close ?? open
        let openLength = (open as NSString).length
        let closeLength = (close as NSString).length

        if selection.location >= openLength, NSMaxRange(selection) + closeLength <= text.length {
            let before = NSRange(location: selection.location - openLength, length: openLength)
            let after = NSRange(location: NSMaxRange(selection), length: closeLength)
            if text.substring(with: before) == open && text.substring(with: after) == close {
                let inner = text.substring(with: selection)
                let whole = NSRange(location: before.location, length: openLength + selection.length + closeLength)
                replace(whole, with: inner, select: NSRange(location: before.location, length: selection.length))
                return
            }
        }

        let inner = selection.length > 0 ? text.substring(with: selection) : placeholder
        replace(
            selection,
            with: open + inner + close,
            select: NSRange(location: selection.location + openLength, length: (inner as NSString).length)
        )
    }

    func insertLink() {
        guard let textView else { return }
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let label = selection.length > 0 ? text.substring(with: selection) : "link text"
        let address = "https://"
        let inserted = "[\(label)](\(address))"
        let addressStart = selection.location + (label as NSString).length + 3
        replace(selection, with: inserted, select: NSRange(location: addressStart, length: (address as NSString).length))
    }

    // MARK: Lines

    func setStyle(_ style: TextStyle) {
        transformLines { lines in
            lines.map { line in
                let stripped = Self.removing(Self.stylePrefix, from: line)
                return style == .normal ? stripped : style.prefix + stripped
            }
        }
        updateCurrentStyle()
    }

    func toggleList(_ kind: ListKind) {
        transformLines { lines in
            let alreadyKind = lines.allSatisfy { Self.listKind(of: $0) == kind || $0.trimmingCharacters(in: .whitespaces).isEmpty }
            var number = 0
            return lines.map { line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                let (indent, body) = Self.splitListPrefix(line)
                if alreadyKind { return indent + body }
                number += 1
                switch kind {
                case .bullet: return indent + "- " + body
                case .numbered: return indent + "\(number). " + body
                case .checklist: return indent + "- [ ] " + body
                }
            }
        }
    }

    // MARK: Blocks

    func insertTable() {
        let table = "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |\n"
        insertBlock(table, select: NSRange(location: 2, length: 8))
    }

    func insertCodeBlock() {
        guard let textView else { return }
        let text = textView.string as NSString
        let selection = textView.selectedRange()
        let inner = selection.length > 0 ? text.substring(with: selection) : ""
        let block = "```\n" + inner + "\n```\n"
        insertBlock(block, select: NSRange(location: 4, length: (inner as NSString).length), replacing: selection)
    }

    private func insertBlock(_ block: String, select: NSRange, replacing range: NSRange? = nil) {
        guard let textView else { return }
        let text = textView.string as NSString
        let target = range ?? textView.selectedRange()
        var prefix = ""
        if target.location > 0 && text.character(at: target.location - 1) != 10 {
            prefix = "\n"
        }
        let prefixLength = (prefix as NSString).length
        replace(
            target,
            with: prefix + block,
            select: NSRange(location: target.location + prefixLength + select.location, length: select.length)
        )
    }

    // MARK: State

    /// Reads the style of the line under the cursor.
    func updateCurrentStyle() {
        guard let textView else { return }
        let text = textView.string as NSString
        let line = text.substring(with: text.lineRange(for: NSRange(location: textView.selectedRange().location, length: 0)))
        if line.hasPrefix("### ") { currentStyle = .heading3 }
        else if line.hasPrefix("## ") { currentStyle = .heading2 }
        else if line.hasPrefix("# ") { currentStyle = .heading1 }
        else if line.hasPrefix(">") { currentStyle = .quote }
        else { currentStyle = .normal }
    }

    // MARK: Helpers

    private func replace(_ range: NSRange, with string: String, select: NSRange? = nil) {
        guard let textView else { return }
        textView.insertText(string, replacementRange: range)
        if let select {
            textView.setSelectedRange(select)
        }
        textView.window?.makeFirstResponder(textView)
    }

    /// Applies a change to every line touched by the selection.
    private func transformLines(_ change: ([String]) -> [String]) {
        guard let textView else { return }
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let block = text.substring(with: lineRange)
        let endsWithNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if endsWithNewline { lines.removeLast() }

        let result = change(lines).joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        let resultLength = (result as NSString).length - (endsWithNewline ? 1 : 0)
        replace(lineRange, with: result, select: NSRange(location: lineRange.location, length: max(0, resultLength)))
    }

    private static func removing(_ expression: NSRegularExpression, from line: String) -> String {
        let range = NSRange(location: 0, length: (line as NSString).length)
        return expression.stringByReplacingMatches(in: line, range: range, withTemplate: "")
    }

    private static func splitListPrefix(_ line: String) -> (indent: String, body: String) {
        let ns = line as NSString
        guard let match = listPrefix.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else {
            let indent = String(line.prefix { $0 == " " || $0 == "\t" })
            return (indent, String(line.dropFirst(indent.count)))
        }
        return (ns.substring(with: match.range(at: 1)), ns.substring(from: NSMaxRange(match.range)))
    }

    private static func listKind(of line: String) -> ListKind? {
        let ns = line as NSString
        guard let match = listPrefix.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let marker = ns.substring(with: match.range(at: 2))
        if marker.contains("[") { return .checklist }
        if marker.first?.isNumber == true { return .numbered }
        return .bullet
    }
}