import AppKit

/// Attribute keys that describe document meaning in Page view.
extension NSAttributedString.Key {
    nonisolated static let msnBlock = NSAttributedString.Key("msnBlock")
    nonisolated static let msnLevel = NSAttributedString.Key("msnLevel")
    nonisolated static let msnBlockID = NSAttributedString.Key("msnBlockID")
    nonisolated static let msnLanguage = NSAttributedString.Key("msnLanguage")
    nonisolated static let msnBold = NSAttributedString.Key("msnBold")
    nonisolated static let msnItalic = NSAttributedString.Key("msnItalic")
    nonisolated static let msnUnderline = NSAttributedString.Key("msnUnderline")
    nonisolated static let msnStrike = NSAttributedString.Key("msnStrike")
    nonisolated static let msnCode = NSAttributedString.Key("msnCode")
    nonisolated static let msnFont = NSAttributedString.Key("msnFont")
    nonisolated static let msnSize = NSAttributedString.Key("msnSize")
    nonisolated static let msnColor = NSAttributedString.Key("msnColor")
    nonisolated static let msnHighlight = NSAttributedString.Key("msnHighlight")
    nonisolated static let msnAlign = NSAttributedString.Key("msnAlign")
    nonisolated static let msnSpacing = NSAttributedString.Key("msnSpacing")
    nonisolated static let msnIndent = NSAttributedString.Key("msnIndent")
}

/// The kind of paragraph in Page view.
enum PageBlock: String {
    case normal
    case title
    case heading1, heading2, heading3, heading4, heading5, heading6
    case quote
    case code
    case raw
    case bullet
    case ordered
    case task
    case taskDone

    init(_ attributes: [NSAttributedString.Key: Any]) {
        self = PageBlock(rawValue: attributes[.msnBlock] as? String ?? "") ?? .normal
    }

    static func heading(_ level: Int) -> PageBlock {
        switch level {
        case ...1: .heading1
        case 2: .heading2
        case 3: .heading3
        case 4: .heading4
        case 5: .heading5
        default: .heading6
        }
    }

    var headingLevel: Int? {
        switch self {
        case .heading1: 1
        case .heading2: 2
        case .heading3: 3
        case .heading4: 4
        case .heading5: 5
        case .heading6: 6
        default: nil
        }
    }

    var isHeading: Bool { headingLevel != nil || self == .title }

    var isList: Bool {
        self == .bullet || self == .ordered || self == .task || self == .taskDone
    }

    var isLiteral: Bool {
        self == .code || self == .raw
    }
}

/// Paragraph alignment.
enum PageAlignment: String, CaseIterable, Identifiable {
    case left, center, right, justify

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        case .justify: "text.justify"
        }
    }

    var textAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        case .justify: .justified
        }
    }
}

/// Fonts offered in the toolbar. Mac fonts plus fonts bundled with the app.
enum PageFont: String, CaseIterable, Identifiable {
    case timesNewRoman = "Times New Roman"
    case georgia = "Georgia"
    case sourceSerif = "Source Serif 4"
    case merriweather = "Merriweather"
    case lora = "Lora"
    case arial = "Arial"
    case helvetica = "Helvetica Neue"
    case inter = "Inter"
    case roboto = "Roboto"
    case openSans = "Open Sans"
    case lato = "Lato"
    case jetBrainsMono = "JetBrains Mono"
    case system = "System"
    case newYork = "New York"
    case menlo = "Menlo"

    var id: String { rawValue }

    /// Name written into the Markdown file.
    var css: String {
        switch self {
        case .system: "system-ui"
        case .newYork: "ui-serif"
        case .menlo: "ui-monospace"
        default: "'\(rawValue)'"
        }
    }

    init?(css: String) {
        let clean = css.trimmingCharacters(in: CharacterSet(charactersIn: "'\" ")).lowercased()
        switch clean {
        case "system-ui": self = .system
        case "ui-serif": self = .newYork
        case "ui-monospace": self = .menlo
        default:
            guard let match = PageFont.allCases.first(where: { $0.rawValue.lowercased() == clean }) else { return nil }
            self = match
        }
    }

    func font(size: CGFloat) -> NSFont {
        switch self {
        case .system:
            return .systemFont(ofSize: size)
        case .newYork:
            return PageStyle.serif(size: size)
        case .menlo:
            return NSFont(name: "Menlo-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        default:
            return NSFontManager.shared.font(withFamily: rawValue, traits: [], weight: 5, size: size)
                ?? .systemFont(ofSize: size)
        }
    }
}

/// Paragraph settings saved as a hidden comment line before the paragraph.
struct ParagraphProps: Equatable {
    var align: PageAlignment = .left
    var spacing: Double = PageStyle.defaultSpacing
    var indent = 0
    var isTitle = false

    init() {}

    init(_ attributes: [NSAttributedString.Key: Any]) {
        align = PageAlignment(rawValue: attributes[.msnAlign] as? String ?? "") ?? .left
        spacing = attributes[.msnSpacing] as? Double ?? PageStyle.defaultSpacing
        indent = attributes[.msnIndent] as? Int ?? 0
    }

    var isDefault: Bool {
        align == .left && abs(spacing - PageStyle.defaultSpacing) < 0.001 && indent == 0 && !isTitle
    }

    var comment: String {
        var parts: [String] = []
        if isTitle { parts.append("title") }
        if align != .left { parts.append("align=\(align.rawValue)") }
        if abs(spacing - PageStyle.defaultSpacing) >= 0.001 { parts.append("spacing=\(String(format: "%g", spacing))") }
        if indent > 0 { parts.append("indent=\(indent)") }
        return "<!-- msn: \(parts.joined(separator: " ")) -->"
    }

    /// Writes non-default values into attributes and clears default ones.
    func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        attributes[.msnAlign] = align == .left ? nil : align.rawValue
        attributes[.msnSpacing] = abs(spacing - PageStyle.defaultSpacing) < 0.001 ? nil : spacing
        attributes[.msnIndent] = indent == 0 ? nil : indent
    }

    static func parse(_ html: String) -> ParagraphProps? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<!-- msn:"), trimmed.hasSuffix("-->") else { return nil }
        let body = trimmed.dropFirst("<!-- msn:".count).dropLast(3)
        var props = ParagraphProps()
        for token in body.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            let pair = token.split(separator: "=", maxSplits: 1).map(String.init)
            switch pair[0] {
            case "title":
                props.isTitle = true
            case "align":
                if pair.count == 2, let value = PageAlignment(rawValue: pair[1]) { props.align = value }
            case "spacing":
                if pair.count == 2, let value = Double(pair[1]) { props.spacing = value }
            case "indent":
                if pair.count == 2, let value = Int(pair[1]) { props.indent = max(0, min(8, value)) }
            default:
                break
            }
        }
        return props
    }
}

/// Reads #RRGGBB colors.
enum Hex {
    static func color(_ hex: String) -> NSColor? {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}