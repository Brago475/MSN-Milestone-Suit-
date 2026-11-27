import AppKit
import SwiftUI

/// File menu items for tabs. Close Tab sits above the window's Close, so ⌘W closes a tab first.
@MainActor
struct TabCommands: Commands {

    let library: LibraryStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { library.newFileInNewTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Close Tab") { closeTab() }
                .keyboardShortcut("w", modifiers: .command)

            Divider()

            Button("Show Next Tab") { library.cycleTabs(by: 1) }
                .keyboardShortcut(.tab, modifiers: .control)
            Button("Show Previous Tab") { library.cycleTabs(by: -1) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
        }
    }

    /// Closes the open tab. Settings, or a window with no tabs, closes normally.
    private func closeTab() {
        let window = NSApp.keyWindow
        let isSettings = window?.identifier?.rawValue.localizedCaseInsensitiveContains("settings") ?? false
        if isSettings || library.tabs.isEmpty {
            window?.performClose(nil)
        } else {
            library.closeActiveTab()
        }
    }
}