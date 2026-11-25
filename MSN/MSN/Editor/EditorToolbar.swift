import SwiftUI

/// Formatting toolbar for Markdown mode.
struct EditorToolbar: View {

    let controller: EditorController
    @Binding var fontSize: Double

    var body: some View {
        HStack(spacing: 2) {
            tool("arrow.uturn.backward", "Undo") { controller.undo() }
            tool("arrow.uturn.forward", "Redo") { controller.redo() }

            separator

            Menu {
                ForEach(TextStyle.allCases) { style in
                    Button(style.rawValue) { controller.setStyle(style) }
                }
            } label: {
                Text(controller.currentStyle.rawValue)
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 116)
            .help("Text style")

            Menu {
                ForEach(11...18, id: \.self) { size in
                    Button("\(size)") { fontSize = Double(size) }
                }
            } label: {
                Text("\(Int(fontSize))")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 52)
            .help("Text size")

            separator

            tool("bold", "Bold") { controller.toggleWrap("**", placeholder: "bold text") }
                .keyboardShortcut("b", modifiers: .command)
            tool("italic", "Italic") { controller.toggleWrap("*", placeholder: "italic text") }
                .keyboardShortcut("i", modifiers: .command)
            tool("underline", "Underline") { controller.toggleWrap("<u>", "</u>", placeholder: "underlined text") }
                .keyboardShortcut("u", modifiers: .command)
            tool("link", "Link") { controller.insertLink() }
                .keyboardShortcut("k", modifiers: [.command, .shift])

            separator

            tool("list.bullet", "Bulleted list") { controller.toggleList(.bullet) }
            tool("list.number", "Numbered list") { controller.toggleList(.numbered) }
            tool("checklist", "Checklist") { controller.toggleList(.checklist) }
            tool("text.alignleft", "Alignment comes with Page view") {}
                .disabled(true)

            separator

            tool("photo.on.rectangle", "Images come in step E3") {}
                .disabled(true)
            tool("tablecells", "Table") { controller.insertTable() }
            tool("chevron.left.forwardslash.chevron.right", "Code block") { controller.insertCodeBlock() }
            tool("lock", "Lock selected text comes with Secrets") {}
                .disabled(true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
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