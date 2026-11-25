import SwiftUI

enum EditorMode: String {
    case page
    case markdown
}

/// Title, folder path, view switch and export actions.
struct EditorHeader: View {

    let title: String
    let path: String
    @Binding var mode: EditorMode

    @AppStorage("filesPanelVisible") private var panelVisible = true

    var body: some View {
        HStack(spacing: 10) {
            if !panelVisible {
                FilesPanelButton()
                    .padding(.trailing, 4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Picker("", selection: $mode) {
                Text("Page").tag(EditorMode.page)
                Text("Markdown").tag(EditorMode.markdown)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)

            Menu {
                Button("Export as PDF…") {}
                Button("Share Encrypted…") {}
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .fixedSize()
            .disabled(true)
            .help("Export comes in the Export phase")

            Button("Update PDF") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .help("PDF updates come in the Export phase")
        }
        .padding(.leading, panelVisible ? 20 : 14)
        .padding(.trailing, 16)
        .frame(height: 48)
    }
}