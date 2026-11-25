import SwiftUI

/// Formatting toolbar. Page view shows the full set, Markdown mode a simpler one.
/// When the window is narrow, less used tools move into the More menu.
struct EditorToolbar: View {

    let commands: any EditorCommands
    @Binding var markdownSize: Double
    @Binding var zoom: Double
    @Binding var paper: PaperSize
    @Binding var margins: MarginPreset

    private let zoomOptions: [Double] = [0.5, 0.75, 0.9, 1, 1.25, 1.5, 2]

    private var rich: Bool { commands.isRichText }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(compact: false)
            row(compact: true)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .clipped()
        .background { shortcutButtons }
    }

    // MARK: Rows

    private func row(compact: Bool) -> some View {
        HStack(spacing: 2) {
            tool("arrow.uturn.backward", "Undo (⌘Z)") { commands.undo() }
            tool("arrow.uturn.forward", "Redo (⇧⌘Z)") { commands.redo() }
            if !compact {
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
            formatGroup(compact: compact)
            separator

            tool("link", "Link (⇧⌘K)") { commands.insertLink() }
            insertMenu

            separator

            if compact {
                moreMenu
            } else {
                paragraphGroup
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func formatGroup(compact: Bool) -> some View {
        tool("bold", "Bold (⌘B)") { commands.toggleBold() }
        tool("italic", "Italic (⌘I)") { commands.toggleItalic() }
        tool("underline", "Underline (⌘U)") { commands.toggleUnderline() }
        tool("strikethrough", "Strikethrough (⇧⌘X)") { commands.toggleStrike() }
        if !compact {
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
            if !compact {
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

    // MARK: Menus

    private var insertMenu: some View {
        Menu {
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
        } label: {
            Text("Insert")
                .font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 4)
        .help("Insert")
    }

    private var moreMenu: some View {
        Menu {
            Button("Superscript") { commands.toggleSuperscript() }
            Button("Subscript") { commands.toggleSubscript() }
            if rich {
                Button(commands.isPainting ? "Stop paint format" : "Paint format") { commands.paintFormat() }
                Button("Clear formatting") { commands.clearFormatting() }
                Divider()
                Menu("Align") {
                    ForEach(PageAlignment.allCases) { alignment in
                        Button {
                            commands.setAlignment(alignment)
                        } label: {
                            Label(alignment.title, systemImage: alignment.symbol)
                        }
                    }
                }
                Menu("Line spacing") {
                    ForEach(PageStyle.spacings, id: \.value) { option in
                        Button(option.name) { commands.setLineSpacing(option.value) }
                    }
                }
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
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 36)
        .help("More")
    }

    private var zoomMenu: some View {
        Menu {
            ForEach(zoomOptions, id: \.self) { level in
                Button("\(Int(level * 100))%") { zoom = level }
            }
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
            ForEach(TextStyle.allCases) { style in
                Button(style.rawValue) { commands.setStyle(style) }
            }
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
            ForEach(PageFont.allCases) { font in
                Button(font.rawValue) { commands.setFont(font) }
            }
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
                ForEach(PageStyle.sizes, id: \.self) { size in
                    Button(Self.format(size)) { commands.setSize(size) }
                }
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
            ForEach(11...18, id: \.self) { size in
                Button("\(size)") { markdownSize = Double(size) }
            }
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
            ForEach(PageAlignment.allCases) { alignment in
                Button {
                    commands.setAlignment(alignment)
                } label: {
                    Label(alignment.title, systemImage: alignment.symbol)
                }
            }
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
            ForEach(PageStyle.spacings, id: \.value) { option in
                Button(option.name) { commands.setLineSpacing(option.value) }
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 40)
        .help("Line spacing")
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
            .padding(.horizontal, 4)
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