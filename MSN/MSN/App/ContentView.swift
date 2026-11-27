import SwiftUI

struct ContentView: View {

    /// Smallest window that still fits the rail, Files and a usable page.
    static let minimumSize = CGSize(width: 720, height: 480)

    @Environment(VaultSession.self) private var vault
    @State private var selection: AppSection = .files
    @State private var pocket = CGSize(width: 78, height: 38)
    @State private var isFullScreen = false

    var body: some View {
        HStack(spacing: 0) {
            IconRail(
                selection: $selection,
                topInset: pocket.height + 12,
                width: max(Theme.railWidth, pocket.width)
            )
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
            sectionView
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.surface)
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                PocketShape(radius: Theme.pocketBend)
                    .fill(Theme.pocket)
                    .frame(width: pocket.width + Theme.pocketBend, height: pocket.height + Theme.pocketBend)
                    .allowsHitTesting(false)

                if isFullScreen {
                    FullScreenControls()
                        .frame(width: pocket.width, height: pocket.height)
                        .transition(.opacity)
                }
            }
        }
        .background(WindowButtonsReader(size: $pocket))
        .background(FullScreenReader(isFullScreen: $isFullScreen))
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    }

    @ViewBuilder
    private var sectionView: some View {
        switch selection {
        case .files:
            FilesView()
        case .secrets where vault.state != .unlocked:
            LockedView()
        default:
            SectionPlaceholder(section: selection)
        }
    }
}

#Preview {
    ContentView()
        .environment(VaultSession())
        .environment(LibraryStore())
}