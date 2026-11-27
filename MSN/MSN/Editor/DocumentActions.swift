import SwiftUI

enum EditorMode: String {
    case page
    case markdown
}

/// Document buttons as a vertical dock beside the paper.
struct DocumentDock: View {

    static let width: CGFloat = 46
    static let margin: CGFloat = 14

    @Binding var mode: EditorMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        VStack(spacing: 4) {
            ModeButton(kind: .page, mode: $mode)
            ModeButton(kind: .markdown, mode: $mode)
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 22, height: 1)
                .padding(.vertical, 2)
            ExportButton()
            UpdatePDFButton(showsTitle: false)
        }
        .padding(5)
        .frame(width: Self.width)
        .background(shape.fill(Theme.surface))
        .overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

/// The same buttons in one row, for the end of the toolbar.
struct DocumentActionsBar: View {

    @Binding var mode: EditorMode
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ModeButton(kind: .page, mode: $mode, size: 28)
                ModeButton(kind: .markdown, mode: $mode, size: 28)
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            ExportButton(size: 30)
            UpdatePDFButton(showsTitle: !compact, size: 30)
        }
    }
}

// MARK: Buttons

private struct ModeButton: View {

    let kind: EditorMode
    @Binding var mode: EditorMode
    var size: CGFloat = 36

    private var isOn: Bool { mode == kind }
    private var title: String { kind == .page ? "Page view" : "Markdown" }

    var body: some View {
        Button {
            mode = kind
        } label: {
            Group {
                if kind == .page {
                    Image(systemName: "doc.text")
                        .font(.system(size: 15, weight: .medium))
                } else {
                    MarkdownGlyph()
                }
            }
            .foregroundStyle(isOn ? Theme.accent : Color.secondary)
            .frame(width: size, height: size)
            .background(
                isOn ? Theme.accent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// "M↓" inside a rounded outline, the common Markdown mark.
private struct MarkdownGlyph: View {
    var body: some View {
        Text("M↓")
            .font(.system(size: 8.5, weight: .bold))
            .padding(.horizontal, 3)
            .frame(height: 13)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 1.3))
    }
}

private struct ExportButton: View {

    var size: CGFloat = 36

    var body: some View {
        Menu {
            Button("Export as PDF…") {}
            Button("Share Encrypted…") {}
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(true)
        .help("Export comes in the Export phase")
        .accessibilityLabel("Export")
    }
}

private struct UpdatePDFButton: View {

    let showsTitle: Bool
    var size: CGFloat = 36

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                if showsTitle {
                    Text("Update PDF")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, showsTitle ? 11 : 0)
            .frame(width: showsTitle ? nil : size, height: showsTitle ? 30 : size)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.45)
        .help("PDF updates come in the Export phase")
        .accessibilityLabel("Update PDF")
    }
}