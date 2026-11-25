import AppKit
import Combine
import SwiftUI

/// The Files section: sidebar tree and file preview.
struct FilesView: View {

    @Environment(LibraryStore.self) private var library

    var body: some View {
        if library.hasLibrary {
            HStack(spacing: 0) {
                FilesSidebar()
                    .frame(width: 268)
                Divider()
                FilePreview(node: library.selectedNode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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