import SwiftUI

private enum TabMetrics {
    static let barHeight: CGFloat = 46
    static let tabHeight: CGFloat = 32
    static let radius: CGFloat = 10
    static let minWidth: CGFloat = 120
    static let maxWidth: CGFloat = 220
    static let spacing: CGFloat = 6
    static let buttonSize: CGFloat = 30
}

/// Open files as outlined tabs that share the bar width, with new file and open tabs list.
struct TabStrip: View {

    @Environment(LibraryStore.self) private var library
    @AppStorage("filesPanelVisible") private var panelVisible = true
    @State private var nameText = ""

    var body: some View {
        HStack(spacing: 0) {
            if !panelVisible {
                FilesPanelButton()
                    .padding(.trailing, 10)
            }

            // minWidth 0 lets extra tabs cut off instead of widening the window.
            HStack(spacing: TabMetrics.spacing) {
                ForEach(library.tabs, id: \.self) { id in
                    if let node = library.index[id] {
                        TabItem(node: node, isActive: id == library.activeTab)
                    }
                }
                BarButton(symbol: "plus", label: "New file", help: "New file in \(folderLabel) (⌘T)") {
                    library.newFileInNewTab()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()

            tabList
                .padding(.leading, 8)
        }
        .padding(.horizontal, 10)
        .frame(height: TabMetrics.barHeight)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Theme.tabBarEdge)
                .frame(height: 1)
        }
        .background(Theme.pocket)
        .alert("Name this file", isPresented: isNaming) {
            TextField("Name", text: $nameText)
            Button("Save") { commitName() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: library.renameRequest, initial: true) { _, url in
            if let url {
                nameText = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    // MARK: Open tabs list

    private var tabList: some View {
        Menu {
            ForEach(library.tabs, id: \.self) { id in
                if let node = library.index[id] {
                    Button {
                        library.activate(id)
                    } label: {
                        if id == library.activeTab {
                            Label(node.name, systemImage: "checkmark")
                        } else {
                            Text(node.name)
                        }
                    }
                }
            }
            Divider()
            Button("Close Other Tabs") {
                if let activeTab = library.activeTab {
                    library.closeOtherTabs(than: activeTab)
                }
            }
            .disabled(library.tabs.count < 2)
        } label: {
            BarButtonLabel(symbol: "chevron.down", isHovered: false)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Open tabs")
    }

    // MARK: Helpers

    private var folderLabel: String {
        guard let folder = library.activeFolder, folder.fileKey != library.rootURL?.fileKey else {
            return library.libraryName
        }
        return library.relativePath(of: folder).replacingOccurrences(of: "/", with: " / ")
    }

    private var isNaming: Binding<Bool> {
        Binding(
            get: { library.renameRequest != nil },
            set: { if !$0 { library.renameRequest = nil } }
        )
    }

    private func commitName() {
        guard let url = library.renameRequest else { return }
        do {
            try library.rename(url, to: nameText)
        } catch {
            library.lastError = error.localizedDescription
        }
    }
}

/// One tab. The open tab is white with a blue outline and a soft blue ring.
private struct TabItem: View {

    @Environment(LibraryStore.self) private var library

    let node: FileNode
    let isActive: Bool

    @State private var isHovered = false
    @State private var closeHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TabMetrics.radius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: node.symbol)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? Theme.accent : Color.secondary)
            Text(node.name)
                .font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            closeButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(minWidth: TabMetrics.minWidth, maxWidth: TabMetrics.maxWidth)
        .frame(height: TabMetrics.tabHeight)
        .background(shape.fill(fill))
        .overlay(shape.strokeBorder(isActive ? Theme.accent : Theme.tabOutline, lineWidth: 1))
        .background {
            if isActive {
                shape
                    .stroke(Theme.accent.opacity(0.14), lineWidth: 3)
                    .padding(-1.5)
            }
        }
        .contentShape(shape)
        .onTapGesture { library.activate(node.id) }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(library.relativePath(of: node.url))
        .contextMenu {
            Button("Rename…") { library.renameRequest = node.url }
            Button("Show in Finder") { library.reveal(node.url) }
            Divider()
            Button("Close Tab") { library.closeTab(node.id) }
            Button("Close Other Tabs") { library.closeOtherTabs(than: node.id) }
                .disabled(library.tabs.count < 2)
        }
    }

    private var fill: Color {
        if isActive { return Theme.surface }
        return isHovered ? Theme.tabHover : Theme.tabIdle
    }

    private var closeButton: some View {
        Button {
            library.closeTab(node.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Color.primary.opacity(closeHovered ? 0.1 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .opacity(isActive || isHovered ? 1 : 0.55)
        .onHover { closeHovered = $0 }
        .help("Close tab (⌘W)")
        .accessibilityLabel("Close \(node.name)")
    }
}

/// Square button in the tab bar, outlined like the tabs.
private struct BarButton: View {

    let symbol: String
    let label: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            BarButtonLabel(symbol: symbol, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(label)
    }
}

private struct BarButtonLabel: View {

    let symbol: String
    let isHovered: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: TabMetrics.buttonSize, height: TabMetrics.buttonSize)
            .background(shape.fill(isHovered ? Theme.tabHover : Theme.tabIdle))
            .overlay(shape.strokeBorder(Theme.tabOutline, lineWidth: 1))
            .contentShape(shape)
    }
}