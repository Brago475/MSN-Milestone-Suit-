import SwiftUI

struct ContentView: View {
    @State private var selection: AppSection = .files

    var body: some View {
        HStack(spacing: 0) {
            IconRail(selection: $selection)
            Divider()
            SectionPlaceholder(section: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1000, minHeight: 680)
    }
}

#Preview {
    ContentView()
}