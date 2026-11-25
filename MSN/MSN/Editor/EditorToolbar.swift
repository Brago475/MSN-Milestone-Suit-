import SwiftUI

/// Formatting toolbar. Page view shows the full set, Markdown mode a simpler one.
struct EditorToolbar: View {

    let commands: any EditorCommands
    @Binding var markdownSize: Double
    @Binding var zoom: Double
    @Binding var paper: PaperSize
    @Binding var margins: MarginPreset

    private let zoomOptions: [Double] = [0.5, 0.75, 0.9, 1, 1.25, 1.5, 2]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                tool("arrow.uturn.backward", "Undo") { commands.undo() }
                tool("arrow.uturn.forward", "Redo") { commands.redo() }
                tool("printer", "Print comes with Export") {}
                    .disabled(true)

                if commands.isRichText {
                    zoomMenu
                    pageSetupMenu
                }

                separator
                styleMenu

                if commands.isRichText {
                    fontMenu
                    separator
                    sizeControl
                } else {
                    markdownSizeMenu
                }

                separator

                tool("bold", "Bold (⌘B)") { commands.toggleBold() }
                    .keyboardShortcut("b", modifiers: .command)
                tool("italic", "Italic (⌘I)") { commands.toggleItalic() }
                    .keyboardShortcut("i", modifiers: .command)
                tool("underline", "Underline (⌘U)") { commands.toggleUnderline() }
                    .keyboardShortcut("u", modifiers: .command)
                tool("strikethrough", "Strikethrough (⇧⌘X)") { commands.toggleStrike() }
                    .keyboardShortcut("x", modifiers: [.command, .shift])

                if commands.isRichText {
                    ColorSwatchButton(symbol: "paintbrush.pointed", help: "Text color", colors: PageStyle.textColors) {
                        commands.setTextColor($0)
                    }
                    ColorSwatchButton(symbol: "highlighter", help: "Highlight", colors: PageStyle.highlightColors) {
                        commands.setHighlight($0)
                    }
                    tool("eraser", "Clear formatting (⌘\\)") { commands.clearFormatting() }
                        .keyboardShortcut("\\", modifiers: .command)
                }

                separator

                tool("link", "Link (⇧⌘K)") { commands.insertLink() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                tool("photo.on.rectangle", "Images come in step E3") {}
                    .disabled(true)

                separator

                if commands.isRichText {
                    alignMenu
                    spacingMenu
                }
                tool("checklist", "Checklist (⇧⌘9)") { commands.toggleList(.checklist) }
                    .keyboardShortcut("9", modifiers: [.command, .shift])
                tool("list.bullet", "Bulleted list (⇧⌘8)") { commands.toggleList(.bullet) }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                tool("list.number", "Numbered list (⇧⌘7)") { commands.toggleList(.numbered) }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                if commands.isRichText {
                    tool("decrease.indent", "Decrease indent (⌘[)") { commands.indent(-1) }
                        .keyboardShortcut("[", modifiers: .command)
                    tool("increase.indent", "Increase indent (⌘])") { commands.indent(1) }
                        .keyboardShortcut("]", modifiers: .command)
                }

                separator

                tool("tablecells", "Table") { commands.insertTable() }
                tool("chevron.left.forwardslash.chevron.right", "Code block") { commands.insertCodeBlock() }
                tool("lock", "Lock selected text comes with Secrets") {}
                    .disabled(true)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
        }
        .frame(height: 40)
        .background { shortcutButtons }
    }

    // MARK: Menus

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
                .keyboardShortcut(",", modifiers: [.command, .shift])
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
                .keyboardShortcut(".", modifiers: [.command, .shift])
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

    /// Hidden buttons for shortcuts whose controls are menus.
    @ViewBuilder
    private var shortcutButtons: some View {
        if commands.isRichText {
            ZStack {
                Button("") { commands.setAlignment(.left) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("") { commands.setAlignment(.center) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("") { commands.setAlignment(.right) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("") { commands.setAlignment(.justify) }
                    .keyboardShortcut("j", modifiers: [.command, .shift])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
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

    private func tool(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}