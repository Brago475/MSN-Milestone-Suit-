import AppKit

/// Converts Page view text back into clean Markdown.
enum MarkdownWriter {

    private struct Line {
        let block: PageBlock
        let level: Int
        let id: String?
        let language: String?
        let props: ParagraphProps
        let range: NSRange
    }

    private enum Mark: CaseIterable {
        case underline, strike, bold, italic

        var open: String {
            switch self {
            case .underline: "<u>"
            case .strike: "~~"
            case .bold: "**"
            case .italic: "*"
            }
        }

        var close: String {
            switch self {
            case .underline: "</u>"
            default: open
            }
        }

        var key: NSAttributedString.Key {
            switch self {
            case .underline: .msnUnderline
            case .strike: .msnStrike
            case .bold: .msnBold
            case .italic: .msnItalic
            }
        }
    }

    static func write(_ result: MarkdownReader.Result) -> String {
        write(result.body, frontMatter: result.frontMatter)
    }

    static func write(_ text: NSAttributedString, frontMatter: String?) -> String {
        let lines = collectLines(text)
        let ns = text.string as NSString
        var chunks: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            switch line.block {
            case .code, .raw:
                var group: [String] = []
                var end = index
                while end < lines.count, lines[end].block == line.block, lines[end].id == line.id {
                    group.append(ns.substring(with: lines[end].range))
                    end += 1
                }
                if line.block == .code {
                    chunks.append("```\(line.language ?? "")\n" + group.joined(separator: "\n") + "\n```")
                } else {
                    chunks.append(group.joined(separator: "\n"))
                }
                index = end

            case .bullet, .ordered, .task, .taskDone:
                var group: [String] = []
                var counters: [Int] = []
                var indents: [String] = [""]
                var end = index
                while end < lines.count, lines[end].block.isList {
                    let item = lines[end]
                    let level = min(item.level, indents.count - 1)
                    if counters.count <= level {
                        counters += Array(repeating: 0, count: level + 1 - counters.count)
                    } else if counters.count > level + 1 {
                        counters.removeSubrange((level + 1)...)
                    }
                    let marker: String
                    switch item.block {
                    case .ordered:
                        counters[level] += 1
                        marker = "\(counters[level]). "
                    case .task:
                        counters[level] = 0
                        marker = "- [ ] "
                    case .taskDone:
                        counters[level] = 0
                        marker = "- [x] "
                    default:
                        counters[level] = 0
                        marker = "- "
                    }
                    let indent = indents[level]
                    group.append(indent + marker + inline(text, item.range))
                    let childIndent = indent + String(repeating: " ", count: item.block == .ordered ? marker.count : 2)
                    if indents.count > level + 1 {
                        indents[level + 1] = childIndent
                        indents.removeSubrange((level + 2)...)
                    } else {
                        indents.append(childIndent)
                    }
                    end += 1
                }
                chunks.append(group.joined(separator: "\n"))
                index = end

            case .quote:
                var group: [String] = []
                var end = index
                while end < lines.count, lines[end].block == .quote {
                    group.append("> " + inline(text, lines[end].range))
                    end += 1
                }
                let body = group.joined(separator: "\n>\n")
                chunks.append(line.props.isDefault ? body : line.props.comment + "\n" + body)
                index = end

            default:
                var props = line.props
                let body: String
                if line.block == .title {
                    props.isTitle = true
                    body = "# " + inline(text, line.range)
                } else if let level = line.block.headingLevel {
                    body = String(repeating: "#", count: level) + " " + inline(text, line.range)
                } else {
                    body = escapeLineStart(inline(text, line.range))
                }
                chunks.append(props.isDefault ? body : props.comment + "\n" + body)
                index += 1
            }
        }

        var markdown = chunks.joined(separator: "\n\n")
        if !markdown.isEmpty { markdown += "\n" }
        if let frontMatter {
            markdown = frontMatter + "\n" + (markdown.isEmpty ? "" : "\n" + markdown)
        }
        return markdown
    }

    // MARK: Lines

    private static func collectLines(_ text: NSAttributedString) -> [Line] {
        let ns = text.string as NSString
        var lines: [Line] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, range, enclosing, _ in
            guard enclosing.length > 0 else { return }
            let attributes = text.attributes(at: enclosing.location, effectiveRange: nil)
            let block = PageBlock(attributes)
            if range.length == 0 && !block.isLiteral { return }
            lines.append(Line(
                block: block,
                level: attributes[.msnLevel] as? Int ?? 0,
                id: attributes[.msnBlockID] as? String,
                language: attributes[.msnLanguage] as? String,
                props: ParagraphProps(attributes),
                range: range
            ))
        }
        return lines
    }

    // MARK: Inline

    /// Writes the inline text of one line with the fewest markers needed.
    private static func inline(_ text: NSAttributedString, _ range: NSRange) -> String {
        guard range.length > 0 else { return "" }
        let ns = text.string as NSString
        var out = ""
        var open: [Mark] = []
        var pending = ""
        var started = false
        var currentSpan: String?
        var currentLink: String?

        func closeMarks() {
            for mark in open.reversed() { out += mark.close }
            open.removeAll()
        }

        func finishGroup() {
            closeMarks()
            if let currentLink { out += "](\(currentLink))" }
            if currentSpan != nil { out += "</span>" }
        }

        text.enumerateAttributes(in: range) { attributes, runRange, _ in
            let raw = ns.substring(with: runRange)
            let span = spanStyle(attributes)
            let link = (attributes[.link] as? URL)?.absoluteString ?? (attributes[.link] as? String)

            if !started || span != currentSpan || link != currentLink {
                if started { finishGroup() }
                out += pending
                pending = ""
                if let span { out += "<span style=\"\(span)\">" }
                if link != nil { out += "[" }
                currentSpan = span
                currentLink = link
                started = true
            }

            let desired = Mark.allCases.filter { attributes[$0.key] != nil }
            let isCode = attributes[.msnCode] != nil
            let (lead, core, trail) = splitWhitespace(raw)

            if core.isEmpty {
                pending += raw
                return
            }
            if let first = open.firstIndex(where: { !desired.contains($0) }) {
                for mark in open[first...].reversed() { out += mark.close }
                open.removeSubrange(first...)
            }
            out += pending + lead
            pending = ""
            for mark in desired where !open.contains(mark) {
                out += mark.open
                open.append(mark)
            }
            out += isCode ? codeSpan(core) : escape(core)
            pending = trail
        }

        if started { finishGroup() }
        out += pending
        return out.replacingOccurrences(of: "\u{2028}", with: "\\\n")
    }

    /// CSS for font, size, color and highlight, or nil when none are set.
    private static func spanStyle(_ attributes: [NSAttributedString.Key: Any]) -> String? {
        var parts: [String] = []
        if let name = attributes[.msnFont] as? String, let font = PageFont(rawValue: name) {
            parts.append("font-family:\(font.css)")
        }
        if let size = attributes[.msnSize] as? Double {
            parts.append("font-size:\(String(format: "%g", size))pt")
        }
        if let color = attributes[.msnColor] as? String {
            parts.append("color:\(color)")
        }
        if let highlight = attributes[.msnHighlight] as? String {
            parts.append("background-color:\(highlight)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    private static func splitWhitespace(_ text: String) -> (String, String, String) {
        let lead = String(text.prefix { $0 == " " || $0 == "\t" })
        let rest = text.dropFirst(lead.count)
        let trail = String(rest.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
        let core = String(rest.dropLast(trail.count))
        return (lead, core, trail)
    }

    private static func codeSpan(_ text: String) -> String {
        text.contains("`") ? "`` \(text) ``" : "`\(text)`"
    }

    /// Escapes characters that Markdown would read as formatting.
    private static func escape(_ text: String) -> String {
        let characters = Array(text)
        var out = ""
        for (index, character) in characters.enumerated() {
            let previous = index > 0 ? characters[index - 1] : nil
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            switch character {
            case "\\", "*", "`", "[", "]":
                out += "\\" + String(character)
            case "_":
                let inWord = (previous?.isLetter == true || previous?.isNumber == true)
                    && (next?.isLetter == true || next?.isNumber == true)
                out += inWord ? "_" : "\\_"
            case "~":
                out += next == "~" || previous == "~" ? "\\~" : "~"
            case "<":
                let tagLike = next?.isLetter == true || next == "/" || next == "!"
                out += tagLike ? "\\<" : "<"
            default:
                out.append(character)
            }
        }
        return out
    }

    /// Escapes a normal paragraph that would otherwise start a heading, list or quote.
    private static func escapeLineStart(_ line: String) -> String {
        guard let first = line.first else { return line }
        if "#>-+=".contains(first) {
            return "\\" + line
        }
        if first.isNumber,
           let match = line.firstMatch(of: /^(\d+)([.)])(\s|$)/) {
            let digits = String(match.1)
            return digits + "\\" + line.dropFirst(digits.count)
        }
        return line
    }
}