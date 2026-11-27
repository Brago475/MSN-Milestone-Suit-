import AppKit
import Combine
import SwiftUI

/// The Files section: vault header, sidebar tree, footer, tabs and the open file. The panel can be hidden.
/// In full screen the Files panel and tab bar slide down with the menu bar.
struct FilesView: View {

    @Environment(LibraryStore.self) private var library
    @Environment(\.menuBarInset) private var menuBarInset
    @AppStorage("filesPanelVisible") private var panelVisible = true

    var body: some View {
        if library.hasLibrary {
            HStack(spacing: 0) {
                if panelVisible {
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            FilesHeader()
                            FilesSidebar()
                            FilesFooter()
                        }
                        .frame(width: 268)
                        .background(.background)

                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(width: 1)
                    }
                    .offset(y: menuBarInset)
                    .zIndex(1)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    if !library.tabs.isEmpty {
                        TabStrip()
                            .offset(y: menuBarInset)
                            .zIndex(1)
                    }
                    FilePreview(node: library.activeNode)
                        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if !panelVisible && library.tabs.isEmpty {
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