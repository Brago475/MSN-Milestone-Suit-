import AppKit
import SwiftUI

/// Live syntax styling for Markdown mode.
enum MarkdownStyle {

    private static func regex(
        _ pattern: String,
        _ options: NSRegularExpression.Options = [.anchorsMatchLines]
    ) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let heading = regex(#"^(#{1,6})[ \t].*$"#)
    private static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let italic = regex(#"(?<![\*\w])([\*_])(?=\S)([^\*_\n]+?)(?<=\S)\1(?![\*\w])"#)
    private static let strike = regex(#"~~(?=\S)(.+?)(?<=\S)~~"#)
    private static let underline = regex(#"<u>(.+?)</u>"#)
    private static let inlineCode = regex(#"`[^`\n]+`"#)
    private static let link = regex(#"(?<!!)\[([^\]\n]+)\]\(([^)\n]+)\)"#)
    private static let image = regex(#"!\[([^\]\n]*)\]\(([^)\n]+)\)"#)
    private static let wikiLink = regex(#"\[\[([^\]\n]+)\]\]"#)
    private static let listMarker = regex(#"^[ \t]*([-*+]|\d+\.)[ \t]"#)
    private static let task = regex(#"^[ \t]*[-*+][ \t]\[([ xX])\][ \t].*$"#)
    private static let quote = regex(#"^>.*$"#)
    private static let rule = regex(#"^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$"#)
    private static let fence = regex(#"^```.*?^```[ \t]*$"#, [.anchorsMatchLines, .dotMatchesLineSeparators])

    static func baseFont(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func baseAttributes(size: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = round(size * 0.4)
        return [
            .font: baseFont(size: size),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    /// Restyles the whole text. Character content is never changed.
    static func apply(to storage: NSTextStorage, baseSize: CGFloat) {
        let string = storage.string
        let full = NSRange(location: 0, length: (string as NSString).length)
        let boldFont = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .bold)
        let italicFont = NSFontManager.shared.convert(baseFont(size: baseSize), toHaveTrait: .italicFontMask)
        let accent = NSColor(Theme.accent)
        let muted = NSColor.tertiaryLabelColor
        let codeBackground = NSColor.quaternaryLabelColor.withAlphaComponent(0.35)

        func each(_ expression: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            expression.enumerateMatches(in: string, range: full) { match, _, _ in
                if let match { body(match) }
            }
        }

        func muteEnds(of range: NSRange, length: Int) {
            storage.addAttribute(.foregroundColor, value: muted, range: NSRange(location: range.location, length: length))
            storage.addAttribute(.foregroundColor, value: muted, range: NSRange(location: NSMaxRange(range) - length, length: length))
        }

        storage.beginEditing()
        storage.setAttributes(baseAttributes(size: baseSize), range: full)

        each(bold) { match in
            storage.addAttribute(.font, value: boldFont, range: match.range)
            muteEnds(of: match.range, length: match.range(at: 1).length)
        }
        each(italic) { match in
            storage.addAttribute(.font, value: italicFont, range: match.range(at: 2))
            muteEnds(of: match.range, length: 1)
        }
        each(strike) { match in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 1))
            muteEnds(of: match.range, length: 2)
        }
        each(underline) { match in
            storage.addAttribute(.foregroundColor, value: muted, range: match.range)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: match.range(at: 1))
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 1))
        }
        each(heading) { match in
            let level = match.range(at: 1).length
            let extra: [CGFloat] = [7, 5, 3, 2, 1, 1]
            let font = NSFont.monospacedSystemFont(ofSize: baseSize + extra[level - 1], weight: .bold)
            storage.addAttribute(.font, value: font, range: match.range)
            storage.addAttribute(.foregroundColor, value: muted, range: match.range(at: 1))
        }
        each(link) { match in
            storage.addAttribute(.foregroundColor, value: muted, range: match.range)
            storage.addAttribute(.foregroundColor, value: accent, range: match.range(at: 1))
        }
        each(image) { match in
            storage.addAttribute(.foregroundColor, value: muted, range: match.range)
        }
        each(wikiLink) { match in
            storage.addAttribute(.foregroundColor, value: accent, range: match.range)
        }
        each(listMarker) { match in
            storage.addAttribute(.foregroundColor, value: accent, range: match.range(at: 1))
            storage.addAttribute(.font, value: boldFont, range: match.range(at: 1))
        }
        each(task) { match in
            let checked = (string as NSString).substring(with: match.range(at: 1)) != " "
            if checked {
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: match.range)
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
        each(quote) { match in
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: match.range)
            storage.addAttribute(.font, value: italicFont, range: match.range)
        }
        each(rule) { match in
            storage.addAttribute(.foregroundColor, value: muted, range: match.range)
        }
        each(inlineCode) { match in
            storage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: match.range)
            storage.addAttribute(.backgroundColor, value: codeBackground, range: match.range)
        }
        each(fence) { match in
            var attributes = baseAttributes(size: baseSize)
            attributes[.foregroundColor] = NSColor.secondaryLabelColor
            attributes[.backgroundColor] = codeBackground
            storage.setAttributes(attributes, range: match.range)
        }

        storage.endEditing()
    }
}