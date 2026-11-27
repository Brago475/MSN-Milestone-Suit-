import SwiftUI

/// Formatting toolbar with four widths. Only the layout that fits is built.
/// Each smaller width moves more tools into the More menu, which is always the last tool.
struct EditorToolbar: View {

    enum Level: Int, Comparable, CaseIterable {
        case full, compact, small, tiny

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let commands: any EditorCommands
    @Binding var markdownSize: Double
    @Binding var zoom: Double
    @Binding var paper: PaperSize
    @Binding var margins: MarginPreset
    @Binding var mode: EditorMode
    let showsActions: Bool

    @State private var width: CGFloat = 0

    private let zoomOptions: [Double] = [0.5, 0.75, 0.9, 1, 1.25, 1.5, 2]

    private var rich: Bool { commands.isRichText }

    var body: some View {
        row(level)
            .padding(.horizontal, 12)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .frame(height: 40)
            .clipped()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .background { shortcutButtons }
    }

    // MARK: Choosing a width

    private var level: Level {
        guard width > 0 else { return .compact }
        let available = width - 24
        for level in Level.allCases {
            let actions = showsActions ? Width.actions(compact: level >= .small) + 12 : 0
            if Width.tools(level, rich: rich) * 1.08 + actions <= available {
                return level
            }
        }
        return .tiny
    }

    /// Widths of each layout, from the fixed sizes of the controls below.
    private enum Width {
        static let tool: CGFloat = 28
        static let gap: CGFloat = 3
        static let separator: CGFloat = 13

        static func tools(_ level: Level, rich: Bool) -> CGFloat {
            var tools = 0, separators = 0
            var menus: [CGFloat] = []
            switch level {
            case .full:
                tools = rich ? 17 : 13
                separators = rich ? 5 : 4
                menus = rich ? [62, 40, 104, 118, 90, 88, 64, 40, 40] : [104, 52, 64]
            case .compact:
                tools = 7
                separators = rich ? 5 : 4
                menus = rich ? [62, 40, 104, 118, 90, 88, 64, 36] : [104, 52, 64, 36]
            case .small:
                tools = 6
                separators = 4
                menus = [104, 36]
            case .tiny:
                tools = 5
                separators = 2
                menus = [36]
            }
            let items = tools + separators + menus.count
            return CGFloat(tools) * tool
                + CGFloat(separators) * separator
                + menus.reduce(0, +)
                + CGFloat(max(0, items - 1)) * gap
        }

        static func actions(compact: Bool) -> CGFloat {
            compact ? 134 : 215
        }
    }

    // MARK: Rows

    private func row(_ level: Level) -> some View {
        HStack(spacing: 0) {
            tools(level)
                .fixedSize()
            Spacer(minLength: 12)
            if showsActions {
                DocumentActionsBar(mode: $mode, compact: level >= .small)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private func tools(_ level: Level) -> some View {
        HStack(spacing: 3) {
            tool("arrow.uturn.backward", "Undo (⌘Z)") { commands.undo() }
            tool("arrow.uturn.forward", "Redo (⇧⌘Z)") { commands.redo() }

            switch level {
            case .full, .compact:
                if level == .full {
                    tool("printer", "Print comes with Export") {}
                        .disabled(true)
                }
                if rich {
                    zoomMenu
                    pageSetupMenu
                }
                separator
                styleMenu
                if rich {
                    fontMenu
                    separator
                    sizeControl
                } else {
                    markdownSizeMenu
                }
                separator
                formatGroup(full: level == .full)
                separator
                tool("link", "Link (⇧⌘K)") { commands.insertLink() }
                insertMenu
                separator
                if level == .full {
                    paragraphGroup
                } else {
                    moreMenu(level)
                }

            case .small:
                separator
                styleMenu
                separator
                basicFormat
                separator
                tool("link", "Link (⇧⌘K)") { commands.insertLink() }
                separator
                moreMenu(level)

            case .tiny:
                separator
                basicFormat
                separator
                moreMenu(level)
            }
        }
    }

    @ViewBuilder
    private var basicFormat: some View {
        tool("bold", "Bold (⌘B)") { commands.toggleBold() }
        tool("italic", "Italic (⌘I)") { commands.toggleItalic() }
        tool("underline", "Underline (⌘U)") { commands.toggleUnderline() }
    }

    @ViewBuilder
    private func formatGroup(full: Bool) -> some View {
        basicFormat
        tool("strikethrough", "Strikethrough (⇧⌘X)") { commands.toggleStrike() }
        if full {
            tool("textformat.superscript", "Superscript (⌃⌘=)") { commands.toggleSuperscript() }
            tool("textformat.subscript", "Subscript (⌃⌘-)") { commands.toggleSubscript() }
        }
        if rich {
            ColorSwatchButton(symbol: "paintbrush.pointed", help: "Text color", colors: PageStyle.textColors) {
                commands.setTextColor($0)
            }
            ColorSwatchButton(symbol: "highlighter", help: "Highlight", colors: PageStyle.highlightColors) {
                commands.setHighlight($0)
            }
            if full {
                tool("paintbrush", "Paint format: copy formatting, then select text to apply it", active: commands.isPainting) {
                    commands.paintFormat()
                }
                tool("eraser", "Clear formatting (⌘\\)") { commands.clearFormatting() }
            }
        }
    }

    @ViewBuilder
    private var paragraphGroup: some View {
        if rich {
            alignMenu
            spacingMenu
        }
        tool("checklist", "Checklist (⇧⌘9)") { commands.toggleList(.checklist) }
        tool("list.bullet", "Bulleted list (⇧⌘8)") { commands.toggleList(.bullet) }
        tool("list.number", "Numbered list (⇧⌘7)") { commands.toggleList(.numbered) }
        if rich {
            tool("decrease.indent", "Decrease indent (⌘[)") { commands.indent(-1) }
            tool("increase.indent", "Increase indent (⌘])") { commands.indent(1) }
        }
    }

    // MARK: More

    /// Holds every tool the current width leaves out.
    private func moreMenu(_ level: Level) -> some View {
        Menu {
            if level >= .small {
                if level == .tiny {
                    Menu("Text style") { styleItems }
                }
                if rich {
                    Menu("Font") { fontItems }
                    Menu("Font size") { sizeItems }
                    Menu("Zoom") { zoomItems }
                    Menu("Page setup") { pageSetupItems }
                } else {
                    Menu("Text size") { markdownSizeItems }
                }
                Divider()
                Button("Strikethrough") { commands.toggleStrike() }
                if level == .tiny {
                    Button("Link") { commands.insertLink() }
                }
                Menu("Insert") { insertItems }
                Divider()
            }
            Button("Superscript") { commands.toggleSuperscript() }
            Button("Subscript") { commands.toggleSubscript() }
            if rich {
                Button(commands.isPainting ? "Stop paint format" : "Paint format") { commands.paintFormat() }
                Button("Clear formatting") { commands.clearFormatting() }
                Divider()
                Menu("Align") { alignItems }
                Menu("Line spacing") { spacingItems }
            }
            Divider()
            Button("Checklist") { commands.toggleList(.checklist) }
            Button("Bulleted list") { commands.toggleList(.bullet) }
            Button("Numbered list") { commands.toggleList(.numbered) }
            if rich {
                Divider()
                Button("Decrease indent") { commands.indent(-1) }
                Button("Increase indent") { commands.indent(1) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 36)
        .help("More")
    }

    // MARK: Menus

    private var insertMenu: some View {
        Menu {
            insertItems
        } label: {
            Text("Insert")
                .font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 4)
        .help("Insert")
    }

    private var zoomMenu: some View {
        Menu {
            zoomItems
        } label: {
            Text("\(Int(zoom * 100))%")
                .font(.system(size: 13))
                .monospacedDigit()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 6)
        .help("Zoom")
    }

    private var pageSetupMenu: some View {
        Menu {
            pageSetupItems
        } label: {
            Image(systemName: "doc.text")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 40)
        .help("Page setup")
    }

    private var styleMenu: some View {
        Menu {
            styleItems
        } label: {
            Text(commands.currentStyle.rawValue)
                .font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 104)
        .help("Text style")
    }

    private var fontMenu: some View {
        Menu {
            fontItems
        } label: {
            Text(commands.currentFont.rawValue)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 118)
        .help("Font")
    }

    private var sizeControl: some View {
        HStack(spacing: 0) {
            tool("minus", "Decrease font size (⇧⌘,)") { commands.stepSize(-1) }
            Menu {
                sizeItems
            } label: {
                Text(Self.format(commands.currentSize))
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 34)
            .help("Font size")
            tool("plus", "Increase font size (⇧⌘.)") { commands.stepSize(1) }
        }
    }

    private var markdownSizeMenu: some View {
        Menu {
            markdownSizeItems
        } label: {
            Text("\(Int(markdownSize))")
                .font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 52)
        .help("Text size")
    }

    private var alignMenu: some View {
        Menu {
            alignItems
        } label: {
            Image(systemName: commands.currentAlignment.symbol)
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 40)
        .help("Align")
    }

    private var spacingMenu: some View {
        Menu {
            spacingItems
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 40)
        .help("Line spacing")
    }

    // MARK: Menu items, shared by the toolbar menus and More

    @ViewBuilder
    private var insertItems: some View {
        Button {} label: { Label("Image", systemImage: "photo") }
            .disabled(true)
        Button { commands.insertTable() } label: { Label("Table", systemImage: "tablecells") }
        Button { commands.insertCodeBlock() } label: {
            Label("Code block", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        Divider()
        Button { commands.insertDivider() } label: { Label("Divider", systemImage: "minus") }
        Button { commands.insertPageBreak() } label: { Label("Page break", systemImage: "rectangle.split.1x2") }
        Menu {
            ForEach(CalloutKind.allCases) { kind in
                Button { commands.insertCallout(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
            }
        } label: {
            Label("Callout", systemImage: "text.bubble")
        }
        Button { commands.insertDate() } label: { Label("Date", systemImage: "calendar") }
        Divider()
        Button {} label: { Label("Lock selected text", systemImage: "lock") }
            .disabled(true)
    }

    @ViewBuilder
    private var zoomItems: some View {
        ForEach(zoomOptions, id: \.self) { level in
            Button("\(Int(level * 100))%") { zoom = level }
        }
    }

    @ViewBuilder
    private var pageSetupItems: some View {
        Section("Paper size") {
            ForEach(PaperSize.allCases) { size in
                Button {
                    paper = size
                } label: {
                    if paper == size {
                        Label("\(size.title)  \(size.detail)", systemImage: "checkmark")
                    } else {
                        Text("\(size.title)  \(size.detail)")
                    }
                }
            }
        }
        Section("Margins") {
            ForEach(MarginPreset.allCases) { preset in
                Button {
                    margins = preset
                } label: {
                    if margins == preset {
                        Label(preset.title, systemImage: "checkmark")
                    } else {
                        Text(preset.title)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var styleItems: some View {
        ForEach(TextStyle.allCases) { style in
            Button(style.rawValue) { commands.setStyle(style) }
        }
    }

    @ViewBuilder
    private var fontItems: some View {
        ForEach(PageFont.allCases) { font in
            Button(font.rawValue) { commands.setFont(font) }
        }
    }

    @ViewBuilder
    private var sizeItems: some View {
        ForEach(PageStyle.sizes, id: \.self) { size in
            Button(Self.format(size)) { commands.setSize(size) }
        }
    }

    @ViewBuilder
    private var markdownSizeItems: some View {
        ForEach(11...18, id: \.self) { size in
            Button("\(size)") { markdownSize = Double(size) }
        }
    }

    @ViewBuilder
    private var alignItems: some View {
        ForEach(PageAlignment.allCases) { alignment in
            Button {
                commands.setAlignment(alignment)
            } label: {
                Label(alignment.title, systemImage: alignment.symbol)
            }
        }
    }

    @ViewBuilder
    private var spacingItems: some View {
        ForEach(PageStyle.spacings, id: \.value) { option in
            Button(option.name) { commands.setLineSpacing(option.value) }
        }
    }

    // MARK: Shortcuts

    /// Shortcuts live here so they keep working when tools move into the More menu.
    private var shortcutButtons: some View {
        ZStack {
            shortcut("b", .command) { commands.toggleBold() }
            shortcut("i", .command) { commands.toggleItalic() }
            shortcut("u", .command) { commands.toggleUnderline() }
            shortcut("x", [.command, .shift]) { commands.toggleStrike() }
            shortcut("=", [.command, .control]) { commands.toggleSuperscript() }
            shortcut("-", [.command, .control]) { commands.toggleSubscript() }
            shortcut("k", [.command, .shift]) { commands.insertLink() }
            shortcut("9", [.command, .shift]) { commands.toggleList(.checklist) }
            shortcut("8", [.command, .shift]) { commands.toggleList(.bullet) }
            shortcut("7", [.command, .shift]) { commands.toggleList(.numbered) }
            if rich {
                richShortcuts
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    @ViewBuilder
    private var richShortcuts: some View {
        shortcut("\\", .command) { commands.clearFormatting() }
        shortcut(",", [.command, .shift]) { commands.stepSize(-1) }
        shortcut(".", [.command, .shift]) { commands.stepSize(1) }
        shortcut("[", .command) { commands.indent(-1) }
        shortcut("]", .command) { commands.indent(1) }
        shortcut("l", [.command, .shift]) { commands.setAlignment(.left) }
        shortcut("e", [.command, .shift]) { commands.setAlignment(.center) }
        shortcut("r", [.command, .shift]) { commands.setAlignment(.right) }
        shortcut("j", [.command, .shift]) { commands.setAlignment(.justify) }
    }

    private func shortcut(_ key: KeyEquivalent, _ modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button("", action: action)
            .keyboardShortcut(key, modifiers: modifiers)
    }

    // MARK: Pieces

    private static func format(_ size: Double) -> String {
        String(format: "%g", size)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 6)
    }

    private func tool(_ symbol: String, _ help: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .background(
                    active ? Theme.accent.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}