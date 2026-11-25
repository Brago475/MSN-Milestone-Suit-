import AppKit
import Combine
import SwiftUI

/// The Files section: vault header, sidebar tree, footer and file preview. The panel can be hidden.
struct FilesView: View {

    @Environment(LibraryStore.self) private var library
    @AppStorage("filesPanelVisible") private var panelVisible = true

    /// Editors show their own show button in the page header.
    private var editorIsOpen: Bool {
        guard let kind = library.selectedNode?.kind else { return false }
        return kind == .markdown || kind == .text
    }

    var body: some View {
        if library.hasLibrary {
            HStack(spacing: 0) {
                if panelVisible {
                    VStack(spacing: 0) {
                        FilesHeader()
                        FilesSidebar()
                        FilesFooter()
                    }
                    .frame(width: 268)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1)
                }

                FilePreview(node: library.selectedNode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        if !panelVisible && !editorIsOpen {
                            FilesPanelButton()
                                .padding(14)
                        }
                    }
            }
            .background {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        panelVisible.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .opacity(0)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                library.reload()
            }
        } else {
            ContentUnavailableView(
                "No vault open",
                systemImage: "folder.badge.questionmark",
                description: Text("This vault's folder can't be found.")
            )
        }
    }
}