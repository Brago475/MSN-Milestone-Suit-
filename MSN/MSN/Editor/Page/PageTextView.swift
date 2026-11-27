import AppKit

/// Text view that draws separate pages, block decorations and list markers.
/// Lines that would cross a page edge, or follow a page break, move to the next page.
final class PageTextView: NSTextView, NSLayoutManagerDelegate {

    static let topGap: CGFloat = 32

    /// Thin line around each page.
    private static let pageOutline = NSColor(srgbRed: 0xB9 / 255, green: 0xBE / 255, blue: 0xC7 / 255, alpha: 1)

    var pageLayout = PageLayout() {
        didSet {
            if pageLayout != oldValue { applyPageLayout() }
        }
    }

    var onToggleTask: ((NSRange) -> Void)?
    var onPageCount: ((Int) -> Void)?
    var onSelectionFinished: (() -> Void)?
    private(set) var pageCount = 1
    private var checkboxHits: [(NSRect, NSRange)] = []

    private var pageX: CGFloat {
        max(16, (bounds.width - pageLayout.width) / 2)
    }

    private func pageRect(_ index: Int) -> NSRect {
        NSRect(
            x: pageX,
            y: Self.topGap + CGFloat(index) * pageLayout.stride,
            width: pageLayout.width,
            height: pageLayout.height
        )
    }

    private func isOnPage(_ point: NSPoint) -> Bool {
        (0..<pageCount).contains { pageRect($0).contains(point) }
    }

    // MARK: Layout

    func applyPageLayout() {
        textContainer?.size = NSSize(width: pageLayout.contentWidth, height: .greatestFiniteMagnitude)
        updateInsets()
        if let storage = textStorage {
            layoutManager?.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: storage.length),
                actualCharacterRange: nil
            )
        }
        updatePageCount()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        var size = newSize
        size.width = max(size.width, pageLayout.width + 32)
        super.setFrameSize(size)
        updateInsets()
    }

    func updateInsets() {
        let inset = NSSize(width: pageX + pageLayout.margin, height: Self.topGap + pageLayout.margin)
        if textContainerInset != inset {
            textContainerInset = inset
        }
    }

    /// Counts pages from the laid out text and grows the view to hold them.
    func updatePageCount() {
        guard let layoutManager, let textContainer else { return }
        let used = layoutManager.usedRect(for: textContainer)
        let bottom = max(used.maxY, layoutManager.extraLineFragmentRect.maxY)
        let pages = max(1, Int((max(0, bottom - 1) / pageLayout.stride).rounded(.down)) + 1)

        if pages != pageCount {
            pageCount = pages
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            let callback = onPageCount
            DispatchQueue.main.async { callback?(pages) }
        }

        let needed = Self.topGap * 2 + CGFloat(pages) * pageLayout.stride - PageLayout.gap
        if abs(minSize.height - needed) > 0.5 {
            minSize = NSSize(width: 0, height: needed)
            if frame.height < needed {
                setFrameSize(NSSize(width: frame.width, height: needed))
            }
        }
    }

    // MARK: Pagination

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        let stride = pageLayout.stride
        let top = lineFragmentRect.pointee.minY
        let height = lineFragmentRect.pointee.height
        let page = (top / stride).rounded(.down)
        let local = top - page * stride

        var shift: CGFloat = 0
        if local > 0.5, followsPageBreak(layoutManager, glyphRange) {
            shift = (page + 1) * stride - top
        } else if local > 0, local + height > pageLayout.contentHeight {
            shift = (page + 1) * stride - top
        }
        guard shift > 0 else { return false }

        lineFragmentRect.pointee.origin.y += shift
        lineFragmentUsedRect.pointee.origin.y += shift
        return true
    }

    /// True when the line is the first one after a page break paragraph.
    private func followsPageBreak(_ layoutManager: NSLayoutManager, _ glyphRange: NSRange) -> Bool {
        guard let storage = layoutManager.textStorage, glyphRange.length > 0 else { return false }
        let index = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        guard index > 0, index <= storage.length else { return false }
        let ns = storage.string as NSString
        guard ns.character(at: index - 1) == 10 else { return false }
        return PageBlock(storage.attributes(at: index - 1, effectiveRange: nil)) == .pageBreak
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        didCompleteLayoutFor textContainer: NSTextContainer?,
        atEnd layoutFinishedFlag: Bool
    ) {
        if layoutFinishedFlag {
            updatePageCount()
        }
    }

    // MARK: Cursor

    /// Text cursor over the paper only. The gray area around it keeps the arrow.
    override func resetCursorRects() {
        for index in 0..<pageCount {
            let rect = pageRect(index).intersection(visibleRect)
            if !rect.isEmpty {
                addCursorRect(rect, cursor: .iBeam)
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if !isOnPage(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isOnPage(convert(event.locationInWindow, from: nil)) {
            super.cursorUpdate(with: event)
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: Drawing

    override func drawBackground(in rect: NSRect) {
        PageStyle.surround.setFill()
        rect.fill()

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: PageStyle.muted
        ]

        for index in 0..<pageCount {
            let page = pageRect(index)
            guard page.insetBy(dx: -24, dy: -24).intersects(rect) else { continue }

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.08)
            shadow.set()
            NSColor.white.setFill()
            page.fill()
            NSGraphicsContext.restoreGraphicsState()

            let outline = NSBezierPath(rect: page.insetBy(dx: 0.5, dy: 0.5))
            outline.lineWidth = 1
            Self.pageOutline.setStroke()
            outline.stroke()

            let number = "\(index + 1)" as NSString
            let size = number.size(withAttributes: numberAttributes)
            number.draw(
                at: NSPoint(
                    x: page.maxX - pageLayout.margin - size.width,
                    y: page.maxY - pageLayout.margin / 2 - size.height / 2
                ),
                withAttributes: numberAttributes
            )
        }

        drawBlockDecorations()
        drawCallouts()
        drawBreaks()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawListMarkers()
    }

    /// Gray boxes behind code and raw blocks, and a bar beside quotes.
    private func drawBlockDecorations() {
        guard let storage = textStorage, let layoutManager, let textContainer, storage.length > 0 else { return }
        let origin = textContainerOrigin

        storage.enumerateAttribute(.msnBlock, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let raw = value as? String, let block = PageBlock(rawValue: raw),
                  block == .code || block == .raw || block == .quote else { return }
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphs.length > 0 else { return }
            let bounds = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
                .offsetBy(dx: origin.x, dy: origin.y)

            if block == .quote {
                PageStyle.rule.setFill()
                NSRect(x: origin.x, y: bounds.minY, width: 3, height: bounds.height).fill()
            } else {
                let box = NSRect(
                    x: origin.x - 12,
                    y: bounds.minY - 8,
                    width: textContainer.size.width + 24,
                    height: bounds.height + 16
                )
                PageStyle.codeFill.setFill()
                NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6).fill()
            }
        }
    }

    /// Tinted box with a colored bar for each callout.
    private func drawCallouts() {
        guard let storage = textStorage, let layoutManager, let textContainer, storage.length > 0 else { return }
        let origin = textContainerOrigin
        let width = textContainer.size.width

        storage.enumerateAttribute(.msnCallout, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let raw = value as? String, let kind = CalloutKind(rawValue: raw) else { return }
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphs.length > 0 else { return }
            let first = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            let last = layoutManager.lineFragmentUsedRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil)
            let box = NSRect(
                x: origin.x,
                y: origin.y + first.minY - 8,
                width: width,
                height: last.maxY - first.minY + 16
            )
            let path = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)
            kind.fill.setFill()
            path.fill()

            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            kind.bar.setFill()
            NSRect(x: box.minX, y: box.minY, width: 4, height: box.height).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// A rule for dividers and a dashed labeled line for page breaks.
    private func drawBreaks() {
        guard let storage = textStorage, let layoutManager, let textContainer, storage.length > 0 else { return }
        let origin = textContainerOrigin
        let width = textContainer.size.width
        let ns = storage.string as NSString
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: PageStyle.muted
        ]

        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
            guard enclosing.length > 0 else { return }
            let block = PageBlock(storage.attributes(at: enclosing.location, effectiveRange: nil))
            guard block.isAtomic else { return }

            let glyph = layoutManager.glyphIndexForCharacter(at: enclosing.location)
            let used = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            let y = (origin.y + used.midY).rounded() + 0.5

            let line = NSBezierPath()
            line.move(to: NSPoint(x: origin.x, y: y))
            line.line(to: NSPoint(x: origin.x + width, y: y))
            line.lineWidth = 1

            if block == .divider {
                PageStyle.rule.setStroke()
                line.stroke()
            } else {
                let pattern: [CGFloat] = [4, 3]
                line.setLineDash(pattern, count: 2, phase: 0)
                PageStyle.muted.withAlphaComponent(0.6).setStroke()
                line.stroke()

                let label = "Page break" as NSString
                let size = label.size(withAttributes: labelAttributes)
                let labelRect = NSRect(
                    x: origin.x + (width - size.width) / 2 - 6,
                    y: y - size.height / 2,
                    width: size.width + 12,
                    height: size.height
                )
                NSColor.white.setFill()
                labelRect.fill()
                label.draw(at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY), withAttributes: labelAttributes)
            }
        }
    }

    /// Bullets, numbers and checkboxes in the list indent.
    private func drawListMarkers() {
        checkboxHits.removeAll()
        guard let storage = textStorage, let layoutManager, storage.length > 0 else { return }
        let ns = storage.string as NSString
        let origin = textContainerOrigin
        var counters: [Int] = []

        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, _, enclosing, _ in
            guard enclosing.length > 0 else { return }
            let attributes = storage.attributes(at: enclosing.location, effectiveRange: nil)
            let block = PageBlock(attributes)
            let level = attributes[.msnLevel] as? Int ?? 0

            guard block.isList else {
                counters.removeAll()
                return
            }
            if counters.count <= level {
                counters += Array(repeating: 0, count: level + 1 - counters.count)
            } else if counters.count > level + 1 {
                counters.removeSubrange((level + 1)...)
            }
            if block == .ordered {
                counters[level] += 1
            } else {
                counters[level] = 0
            }

            let glyph = layoutManager.glyphIndexForCharacter(at: enclosing.location)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = origin.y + line.minY + layoutManager.location(forGlyphAt: glyph).y
            let x = origin.x + PageStyle.listIndent(level) - 28

            switch block {
            case .bullet:
                self.drawMarker(level % 2 == 0 ? "•" : "◦", rightEdge: x + 16, baseline: baseline)
            case .ordered:
                self.drawMarker("\(counters[level]).", rightEdge: x + 20, baseline: baseline)
            case .task, .taskDone:
                let box = NSRect(x: x + 2, y: baseline - 12, width: 14, height: 14)
                self.drawCheckbox(box, checked: block == .taskDone)
                self.checkboxHits.append((box.insetBy(dx: -4, dy: -4), enclosing))
            default:
                break
            }
        }
    }

    private func drawMarker(_ marker: String, rightEdge: CGFloat, baseline: CGFloat) {
        let font = PageStyle.font(.normal, semantic: [:])
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: PageStyle.body]
        let text = marker as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: rightEdge - size.width, y: baseline - font.ascender), withAttributes: attributes)
    }

    private func drawCheckbox(_ box: NSRect, checked: Bool) {
        let path = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)
        if checked {
            PageStyle.accent.setFill()
            path.fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + 3.5, y: box.midY))
            check.line(to: NSPoint(x: box.minX + 6, y: box.maxY - 3.5))
            check.line(to: NSPoint(x: box.maxX - 3, y: box.minY + 3.5))
            check.lineWidth = 1.8
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor.white.setStroke()
            check.stroke()
        } else {
            path.lineWidth = 1.3
            PageStyle.muted.setStroke()
            path.stroke()
        }
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let hit = checkboxHits.first(where: { $0.0.contains(point) }) {
            onToggleTask?(hit.1)
            return
        }
        super.mouseDown(with: event)
        onSelectionFinished?()
    }

    /// Pasted text is read as Markdown, so formatting carries over.
    override func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string),
              let storage = textStorage else {
            super.paste(sender)
            return
        }
        let parsed = MarkdownReader.read(string).body
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: parsed.string) else { return }
        storage.replaceCharacters(in: range, with: parsed)
        PageStyle.restyle(storage, around: NSRange(location: range.location, length: parsed.length))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + parsed.length, length: 0))
    }
}