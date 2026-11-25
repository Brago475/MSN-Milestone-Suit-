import SwiftUI

struct ContentView: View {

    @Environment(VaultSession.self) private var vault
    @State private var selection: AppSection = .files

    var body: some View {
        HStack(spacing: 0) {
            IconRail(selection: $selection)
            Divider()
            sectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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