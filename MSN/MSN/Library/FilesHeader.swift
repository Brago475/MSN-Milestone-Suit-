import SwiftUI

/// Top of the Files panel: vault switcher and the hide button.
struct FilesHeader: View {

    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(library.vaults, id: \.id) { record in
                    Button {
                        switchTo(record)
                    } label: {
                        if record.id == VaultRegistry.currentID {
                            Label(record.name, systemImage: "checkmark")
                        } else {
                            Text(record.name)
                        }
                    }
                }
                Divider()
                Button("Show in Finder") {
                    if let url = library.rootURL {
                        library.reveal(url)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(library.libraryName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.primary.opacity(0.07), in: Capsule())
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Switch vault")

            Spacer(minLength: 4)

            FilesPanelButton()
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    private func switchTo(_ record: VaultRecord) {
        guard record.id != VaultRegistry.currentID else { return }
        do {
            try library.open(record)
        } catch {
            library.lastError = error.localizedDescription
        }
    }
}

/// Bottom of the Files panel: logo, app name and Settings.
struct FilesFooter: View {

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityLabel("MSN")

            Text("Milestone Suit")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 56)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }
}

/// Shows or hides the Files panel. Shared by the Files header, the page header and the welcome screen.
struct FilesPanelButton: View {

    @AppStorage("filesPanelVisible") private var panelVisible = true

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                panelVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 28)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(panelVisible ? "Hide files panel (⌃⌘S)" : "Show files panel (⌃⌘S)")
        .accessibilityLabel(panelVisible ? "Hide files panel" : "Show files panel")
    }
}