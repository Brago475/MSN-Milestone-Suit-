import AppKit
import Markdown

/// Converts Markdown into the attributed text used by Page view.
final class MarkdownReader {

    struct Result {
        let frontMatter: String?
        let body: NSAttributedString
    }

    private struct InlineStyle {
        var bold = false
        var italic = false
        var strike = false
        var underline = false
        var code = false
        var link: String?
    }

    private struct SpanStyle {
        var font: String?
        var size: Double?
        var color: String?
        var highlight: String?
    }

    private struct Context {
        var block: PageBlock
        var level = 0
        var id: String?
        var language: String?
        var props = ParagraphProps()
        var callout: String?
    }

    private let output = NSMutableAttributedString()
    private var underlineDepth = 0
    private var superDepth = 0
    private var subDepth = 0
    private var spans: [SpanStyle] = []
    private var pendingProps: ParagraphProps?

    private static let styleAttribute = try! NSRegularExpression(pattern: #"style\s*=\s*["']([^"']*)["']"#, options: [.caseInsensitive])

    static func read(_ markdown: String) -> Result {
        let (frontMatter, body) = splitFrontMatter(markdown)
        let reader = MarkdownReader()
        let document = Document(parsing: body)
        for child in document.children {
            reader.block(child, listLevel: 0)
        }
        if reader.output.string.hasSuffix("\n") {
            reader.output.deleteCharacters(in: NSRange(location: reader.output.length - 1, length: 1))
        }
        return Result(frontMatter: frontMatter, body: reader.output)
    }

    /// Separates YAML front matter so it is kept exactly as written.
    static func splitFrontMatter(_ markdown: String) -> (String?, String) {
        guard markdown.hasPrefix("---\n") else { return (nil, markdown) }
        let searchStart = markdown.index(markdown.startIndex, offsetBy: 4)
        guard let close = markdown.range(of: "\n---", range: searchStart..<markdown.endIndex) else {
            return (nil, markdown)
        }
        let afterClose = close.upperBound
        if afterClose == markdown.endIndex {
            return (String(markdown[..<afterClose]), "")
        }
        guard markdown[afterClose] == "\n" else { return (nil, markdown) }
        let frontMatter = String(markdown[..<afterClose])
        let rest = String(markdown[markdown.index(after: afterClose)...])
        return (frontMatter, rest)
    }

    private func takeProps() -> ParagraphProps {
        defer { pendingProps = nil }
        return pendingProps ?? ParagraphProps()
    }

    // MARK: Blocks

    private func block(_ markup: Markup, listLevel: Int) {
        switch markup {
        case let html as HTMLBlock:
            let trimmed = html.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == PageBlock.pageBreakMarker {
                pendingProps = nil
                atomic(.pageBreak)
            } else if let props = ParagraphProps.parse(html.rawHTML) {
                pendingProps = props
            } else {
                pendingProps = nil
                lines(html.rawHTML, Context(block: .raw, id: UUID().uuidString))
            }
        case is ThematicBreak:
            pendingProps = nil
            atomic(.divider)
        case let heading as Heading:
            let props = takeProps()
            let kind: PageBlock = props.isTitle && heading.level == 1 ? .title : .heading(heading.level)
            paragraph(heading, Context(block: kind, props: props))
        case let paragraph as Paragraph:
            self.paragraph(paragraph, Context(block: .normal, props: takeProps()))
        case let quote as BlockQuote:
            let props = takeProps()
            if let kind = Self.calloutKind(quote) {
                callout(quote, kind: kind)
            } else {
                for child in quote.children {
                    if let paragraph = child as? Paragraph {
                        self.paragraph(paragraph, Context(block: .quote, props: props))
                    } else {
                        block(child, listLevel: 0)
                    }
                }
            }
        case let code as CodeBlock:
            pendingProps = nil
            lines(code.code, Context(block: .code, id: UUID().uuidString, language: code.language))
        case let list as UnorderedList:
            pendingProps = nil
            for item in list.listItems {
                listItem(item, ordered: false, level: listLevel)
            }
        case let list as OrderedList:
            pendingProps = nil
            for item in list.listItems {
                listItem(item, ordered: true, level: listLevel)
            }
        default:
            pendingProps = nil
            lines(markup.format(), Context(block: .raw, id: UUID().uuidString))
        }
    }

    /// Divider and page break paragraphs hold one invisible character.
    private func atomic(_ kind: PageBlock) {
        append(PageBlock.placeholder + "\n", InlineStyle(), Context(block: kind))
    }

    // MARK: Callouts

    private static func calloutKind(_ quote: BlockQuote) -> CalloutKind? {
        guard let first = quote.child(at: 0) as? Paragraph else { return nil }
        let text = first.plainText.lowercased()
        return CalloutKind.allCases.first { text.hasPrefix("[!\($0.rawValue)]") }
    }

    private func callout(_ quote: BlockQuote, kind: CalloutKind) {
        let context = Context(block: .callout, id: UUID().uuidString, callout: kind.rawValue)
        var isFirst = true
        for child in quote.children {
            if let paragraph = child as? Paragraph {
                let start = output.length
                self.paragraph(paragraph, context)
                if isFirst {
                    stripCalloutMarker(from: start)
                    isFirst = false
                }
            } else {
                block(child, listLevel: 0)
            }
        }
    }

    /// Removes the [!kind] marker from the start of the first callout paragraph.
    private func stripCalloutMarker(from start: Int) {
        let ns = output.string as NSString
        guard start < ns.length else { return }
        let rest = ns.substring(from: start)
        guard let match = rest.firstMatch(of: /^\[![A-Za-z]+\][ \t]*/) else { return }
        let length = (String(rest[match.range]) as NSString).length
        output.deleteCharacters(in: NSRange(location: start, length: length))
    }

    // MARK: Lists and paragraphs

    private func listItem(_ item: ListItem, ordered: Bool, level: Int) {
        let kind: PageBlock
        switch item.checkbox {
        case .checked?: kind = .taskDone
        case .unchecked?: kind = .task
        case nil: kind = ordered ? .ordered : .bullet
        }
        for child in item.children {
            if let paragraph = child as? Paragraph {
                self.paragraph(paragraph, Context(block: kind, level: level))
            } else if child is UnorderedList || child is OrderedList {
                block(child, listLevel: level + 1)
            } else {
                block(child, listLevel: level)
            }
        }
    }

    private func paragraph(_ container: Markup, _ context: Context) {
        underlineDepth = 0
        superDepth = 0
        subDepth = 0
        spans.removeAll()
        for child in container.children {
            inline(child, InlineStyle(), context)
        }
        append("\n", InlineStyle(), context)
    }

    private func lines(_ text: String, _ context: Context) {
        var body = text
        while body.hasSuffix("\n") { body.removeLast() }
        for line in body.components(separatedBy: "\n") {
            append(line + "\n", InlineStyle(), context)
        }
    }

    // MARK: Inline

    private func inline(_ markup: Markup, _ style: InlineStyle, _ context: Context) {
        switch markup {
        case let text as Markdown.Text:
            append(text.string, style, context)
        case let strong as Strong:
            var next = style
            next.bold = true
            for child in strong.children { inline(child, next, context) }
        case let emphasis as Emphasis:
            var next = style
            next.italic = true
            for child in emphasis.children { inline(child, next, context) }
        case let strike as Strikethrough:
            var next = style
            next.strike = true
            for child in strike.children { inline(child, next, context) }
        case let code as InlineCode:
            var next = style
            next.code = true
            append(code.code, next, context)
        case let link as Markdown.Link:
            var next = style
            next.link = link.destination
            for child in link.children { inline(child, next, context) }
        case is SoftBreak:
            append(" ", style, context)
        case is LineBreak:
            append("\u{2028}", style, context)
        case let html as InlineHTML:
            inlineHTML(html.rawHTML, style, context)
        default:
            append(markup.format(), style, context)
        }
    }

    private func inlineHTML(_ raw: String, _ style: InlineStyle, _ context: Context) {
        let tag = raw.lowercased()
        switch tag {
        case "<u>":
            underlineDepth += 1
        case "</u>":
            underlineDepth = max(0, underlineDepth - 1)
        case "<sup>":
            superDepth += 1
        case "</sup>":
            superDepth = max(0, superDepth - 1)
        case "<sub>":
            subDepth += 1
        case "</sub>":
            subDepth = max(0, subDepth - 1)
        case "</span>", "</mark>":
            if !spans.isEmpty { spans.removeLast() }
        default:
            if tag.hasPrefix("<mark") {
                spans.append(SpanStyle(highlight: "#FFF3A3"))
            } else if tag.hasPrefix("<span") {
                spans.append(parseSpan(raw))
            } else {
                append(raw, style, context)
            }
        }
    }

    private func parseSpan(_ raw: String) -> SpanStyle {
        var span = SpanStyle()
        let range = NSRange(location: 0, length: (raw as NSString).length)
        guard let match = Self.styleAttribute.firstMatch(in: raw, range: range) else { return span }
        let declarations = (raw as NSString).substring(with: match.range(at: 1))

        for declaration in declarations.split(separator: ";") {
            let pair = declaration.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard pair.count == 2 else { continue }
            let value = pair[1]
            switch pair[0].lowercased() {
            case "font-family":
                let first = value.split(separator: ",").first.map(String.init) ?? value
                span.font = PageFont(css: first)?.rawValue
            case "font-size":
                let lower = value.lowercased()
                if lower.hasSuffix("pt"), let number = Double(lower.dropLast(2)) {
                    span.size = number
                } else if lower.hasSuffix("px"), let number = Double(lower.dropLast(2)) {
                    span.size = (number * 0.75).rounded()
                }
            case "color":
                if value.hasPrefix("#") { span.color = value.uppercased() }
            case "background-color", "background":
                if value.hasPrefix("#") { span.highlight = value.uppercased() }
            default:
                break
            }
        }
        return span
    }

    private func append(_ string: String, _ style: InlineStyle, _ context: Context) {
        var attributes: [NSAttributedString.Key: Any] = [
            .msnBlock: context.block.rawValue,
            .msnLevel: context.level
        ]
        context.props.apply(to: &attributes)
        if let id = context.id { attributes[.msnBlockID] = id }
        if let language = context.language, !language.isEmpty { attributes[.msnLanguage] = language }
        if let callout = context.callout { attributes[.msnCallout] = callout }
        if style.bold { attributes[.msnBold] = true }
        if style.italic { attributes[.msnItalic] = true }
        if style.strike { attributes[.msnStrike] = true }
        if style.underline || underlineDepth > 0 { attributes[.msnUnderline] = true }
        if superDepth > 0 {
            attributes[.msnSuper] = true
        } else if subDepth > 0 {
            attributes[.msnSub] = true
        }
        if style.code { attributes[.msnCode] = true }
        if let link = style.link { attributes[.link] = link }

        for span in spans {
            if let font = span.font { attributes[.msnFont] = font }
            if let size = span.size { attributes[.msnSize] = size }
            if let color = span.color { attributes[.msnColor] = color }
            if let highlight = span.highlight { attributes[.msnHighlight] = highlight }
        }
        output.append(NSAttributedString(string: string, attributes: attributes))
    }
}