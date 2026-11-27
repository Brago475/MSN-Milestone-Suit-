import SwiftUI

/// Pages, word count, save status and view name under the editor.
/// Narrow windows drop whole items instead of cutting text.
struct EditorStatusBar: View {

    let document: MarkdownDocument
    let mode: EditorMode
    let pageCount: Int

    var body: some View {
        // Counted once per update and shared by every layout.
        let counts = Counts(words: document.wordCount, characters: document.characterCount)

        ViewThatFits(in: .horizontal) {
            row(counts, pages: true, characters: true, viewName: true)
            row(counts, pages: true, characters: false, viewName: true)
            row(counts, pages: true, characters: false, viewName: false)
            row(counts, pages: false, characters: false, viewName: false)
            saveLabel
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .lineLimit(1)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 28)
        .clipped()
    }

    private struct Counts {
        let words: Int
        let characters: Int
    }

    private func row(_ counts: Counts, pages: Bool, characters: Bool, viewName: Bool) -> some View {
        HStack(spacing: 18) {
            if pages && mode == .page {
                Text(pageCount == 1 ? "1 page" : "\(pageCount) pages")
            }
            Text("\(counts.words) words")
            if characters {
                Text("\(counts.characters) characters")
            }
            saveLabel
            Spacer(minLength: 12)
            if viewName {
                Text(mode == .page ? "Page view" : "Markdown")
            }
        }
    }

    @ViewBuilder
    private var saveLabel: some View {
        switch document.saveState {
        case .saved:
            Label("Saved as \(document.fileName)", systemImage: "checkmark.circle")
        case .editing:
            Label("Editing…", systemImage: "pencil")
        case .failed:
            Label("Could not save", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}