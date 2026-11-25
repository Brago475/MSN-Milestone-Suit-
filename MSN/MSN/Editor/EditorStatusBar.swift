import SwiftUI

/// Word count and save status under the editor.
struct EditorStatusBar: View {

    let document: MarkdownDocument

    var body: some View {
        HStack(spacing: 18) {
            Text("\(document.wordCount) words")
            Text("\(document.characterCount) characters")
            saveLabel
            Spacer()
            Text("Markdown")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 28)
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