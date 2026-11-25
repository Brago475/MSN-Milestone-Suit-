import SwiftUI

struct ContentView: View {

    @Environment(VaultSession.self) private var vault
    @State private var selection: AppSection = .files
    @State private var pocket = CGSize(width: 78, height: 38)

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.surface)
        .overlay(alignment: .topLeading) {
            PocketShape(radius: Theme.pocketBend)
                .fill(Theme.pocket)
                .frame(width: pocket.width + Theme.pocketBend, height: pocket.height + Theme.pocketBend)
                .allowsHitTesting(false)
        }
        .background(WindowButtonsReader(size: $pocket))
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1000, minHeight: 680)
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