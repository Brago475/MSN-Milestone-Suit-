import AppKit
import SwiftUI

/// Fonts, colors and spacing for Page view. The page is always printed white.
enum PageStyle {

    /// Points on screen per printed point. Matches Google Docs at 100%.
    static let scale: CGFloat = 96.0 / 72.0

    static let defaultSpacing = 1.15
    static let indentStep: CGFloat = 48

    static let ink = NSColor.black
    static let body = NSColor.black
    static let muted = NSColor(srgbRed: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255, alpha: 1)
    static let rule = NSColor(srgbRed: 0xD1 / 255, green: 0xD1 / 255, blue: 0xD6 / 255, alpha: 1)
    static let codeFill = NSColor(srgbRed: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF6 / 255, alpha: 1)
    static let codeInk = NSColor(srgbRed: 0xB4 / 255, green: 0x23 / 255, blue: 0x5B / 255, alpha: 1)
    static let selection = NSColor(srgbRed: 0xB3 / 255, green: 0xD7 / 255, blue: 0xFF / 255, alpha: 1)
    static let accent = NSColor(Theme.accent)

    /// Gray area around the pages.
    static let surround = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x16 / 255, green: 0x16 / 255, blue: 0x17 / 255, alpha: 1)
            : NSColor(srgbRed: 0xEC / 255, green: 0xEC / 255, blue: 0xEF / 255, alpha: 1)
    }

    static let textColors: [(name: String, hex: String)] = [
        ("Black", "#000000"), ("Gray", "#6E6E73"), ("Red", "#D92D20"), ("Orange", "#E8590C"), ("Gold", "#B7791F"),
        ("Green", "#2F9E44"), ("Teal", "#0C8599"), ("Blue", "#0A5FE8"), ("Purple", "#7048E8"), ("Pink", "#C2255C")
    ]

    static let highlightColors: [(name: String, hex: String)] = [
        ("Yellow", "#FFF3A3"), ("Green", "#D3F9D8"), ("Blue", "#D0EBFF"), ("Pink", "#FFDEEB"), ("Orange", "#FFE8CC"),
        ("Purple", "#E5DBFF"), ("Teal", "#C3FAE8"), ("Red", "#FFE3E3"), ("Gray", "#E9ECEF"), ("Sand", "#F3EDE2")
    ]

    static let sizes: [Double] = [8, 9, 10, 11, 12, 14, 18, 24, 30, 36, 48]

    static let spacings: [(name: String, value: Double)] = [
        ("Single", 1.0), ("1.15", 1.15), ("1.5", 1.5), ("Double", 2.0)
    ]

    static func listIndent(_ level: Int) -> CGFloat {
        CGFloat(level + 1) * 36
    }

    // MARK: Defaults

    static func defaultSize(_ block: PageBlock) -> Double {
        switch block {
        case .title: 26
        case .heading1: 20
        case .heading2: 16
        case .heading3: 14
        case .heading4, .heading5, .heading6: 12
        case .code, .raw: 10
        default: 12
        }
    }

    static func defaultFont(_ block: PageBlock) -> PageFont {
        switch block {
        case .code, .raw: .jetBrainsMono
        default: .timesNewRoman
        }
    }

    // MARK: Fonts

    static func serif(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    static func font(_ block: PageBlock, semantic: [NSAttributedString.Key: Any]) -> NSFont {
        let isCode = semantic[.msnCode] != nil && !block.isLiteral
        let family: PageFont = isCode
            ? .jetBrainsMono
            : (PageFont(rawValue: semantic[.msnFont] as? String ?? "") ?? defaultFont(block))
        let points = semantic[.msnSize] as? Double ?? (isCode ? defaultSize(block) - 1 : defaultSize(block))

        var font = family.font(size: CGFloat(points) * scale)
        if block.isHeading || semantic[.msnBold] != nil {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if semantic[.msnItalic] != nil || block == .quote {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }

    // MARK: Paragraphs

    /// Paragraph style. Code and raw blocks get space only at their first and last line.
    static func paragraphStyle(
        _ block: PageBlock,
        level: Int,
        props: ParagraphProps,
        groupStart: Bool = false,
        groupEnd: Bool = false
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = props.align.textAlignment
        style.lineHeightMultiple = block.isLiteral ? 1.1 : props.spacing
        style.paragraphSpacing = 6 * scale

        switch block {
        case .title:
            style.paragraphSpacing = 6 * scale
        case .heading1:
            style.paragraphSpacingBefore = 18 * scale
            style.paragraphSpacing = 6 * scale
        case .heading2:
            style.paragraphSpacingBefore = 14 * scale
            style.paragraphSpacing = 4 * scale
        case .heading3, .heading4, .heading5, .heading6:
            style.paragraphSpacingBefore = 12 * scale
            style.paragraphSpacing = 4 * scale
        case .code, .raw:
            style.paragraphSpacingBefore = groupStart ? 10 * scale : 0
            style.paragraphSpacing = groupEnd ? 12 * scale : 0
        case .bullet, .ordered, .task, .taskDone:
            style.paragraphSpacing = 2 * scale
        default:
            break
        }

        let indent: CGFloat
        if block.isList {
            indent = listIndent(level)
        } else {
            indent = CGFloat(props.indent) * indentStep + (block == .quote ? 16 : 0)
        }
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        return style
    }

    // MARK: Attributes

    /// Visual attributes for a run, built from its meaning.
    static func visualAttributes(
        block: PageBlock,
        level: Int,
        props: ParagraphProps,
        semantic: [NSAttributedString.Key: Any],
        groupStart: Bool = false,
        groupEnd: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        let isCode = semantic[.msnCode] != nil && !block.isLiteral
        let underline = semantic[.msnUnderline] != nil
        let strike = semantic[.msnStrike] != nil || block == .taskDone
        let link = semantic[.link] != nil

        var color: NSColor = block.isHeading ? ink : body
        if block == .quote || block == .taskDone || block == .raw { color = muted }
        if isCode { color = codeInk }
        if link { color = accent }
        if let hex = semantic[.msnColor] as? String, let custom = Hex.color(hex) { color = custom }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(block, semantic: semantic),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(block, level: level, props: props, groupStart: groupStart, groupEnd: groupEnd)
        ]
        if underline || link {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if strike {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let hex = semantic[.msnHighlight] as? String, let fill = Hex.color(hex) {
            attributes[.backgroundColor] = fill
        } else if isCode {
            attributes[.backgroundColor] = codeFill
        }
        return attributes
    }

    /// Full attributes for new text of a given kind.
    static func typingAttributes(
        block: PageBlock,
        level: Int = 0,
        props: ParagraphProps = ParagraphProps(),
        semantic: [NSAttributedString.Key: Any] = [:]
    ) -> [NSAttributedString.Key: Any] {
        var attributes = semantic
        attributes[.msnBlock] = block.rawValue
        attributes[.msnLevel] = level
        props.apply(to: &attributes)
        attributes[.underlineStyle] = nil
        attributes[.strikethroughStyle] = nil
        attributes[.backgroundColor] = nil
        for (key, value) in visualAttributes(block: block, level: level, props: props, semantic: semantic) {
            attributes[key] = value
        }
        return attributes
    }

    // MARK: Restyle

    static func restyleAll(_ storage: NSTextStorage) {
        restyle(storage, around: NSRange(location: 0, length: storage.length))
    }

    /// Restyles paragraphs touched by a range plus their neighbors.
    /// Each paragraph takes the settings of its first character.
    static func restyle(_ storage: NSTextStorage, around range: NSRange) {
        let text = storage.string as NSString
        guard text.length > 0 else { return }
        let start = max(0, min(range.location, text.length) - 1)
        let end = min(text.length, min(range.location, text.length) + max(0, range.length) + 1)
        let target = text.paragraphRange(for: NSRange(location: start, length: end - start))

        var paragraphs: [NSRange] = []
        text.enumerateSubstrings(in: target, options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
            paragraphs.append(enclosing)
        }

        storage.beginEditing()
        for paragraph in paragraphs where paragraph.length > 0 {
            styleParagraph(storage, paragraph)
        }
        storage.endEditing()
    }

    private static func styleParagraph(_ storage: NSTextStorage, _ range: NSRange) {
        let first = storage.attributes(at: range.location, effectiveRange: nil)
        let block = PageBlock(first)
        let level = first[.msnLevel] as? Int ?? 0
        let props = ParagraphProps(first)

        storage.addAttribute(.msnBlock, value: block.rawValue, range: range)
        storage.addAttribute(.msnLevel, value: level, range: range)
        for key in [NSAttributedString.Key.msnBlockID, .msnLanguage, .msnAlign, .msnSpacing, .msnIndent] {
            if let value = first[key] {
                storage.addAttribute(key, value: value, range: range)
            } else {
                storage.removeAttribute(key, range: range)
            }
        }

        var groupStart = false
        var groupEnd = false
        if block.isLiteral {
            let id = first[.msnBlockID] as? String
            func sameGroup(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
                PageBlock(attributes) == block && attributes[.msnBlockID] as? String == id
            }
            groupStart = range.location == 0
                || !sameGroup(storage.attributes(at: range.location - 1, effectiveRange: nil))
            let next = NSMaxRange(range)
            groupEnd = next >= storage.length
                || !sameGroup(storage.attributes(at: next, effectiveRange: nil))
        }

        storage.removeAttribute(.underlineStyle, range: range)
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.removeAttribute(.backgroundColor, range: range)

        var runs: [(NSRange, [NSAttributedString.Key: Any])] = []
        storage.enumerateAttributes(in: range) { attributes, runRange, _ in
            runs.append((runRange, attributes))
        }
        for (runRange, attributes) in runs {
            storage.addAttributes(
                visualAttributes(
                    block: block,
                    level: level,
                    props: props,
                    semantic: attributes,
                    groupStart: groupStart,
                    groupEnd: groupEnd
                ),
                range: runRange
            )
        }
    }
}