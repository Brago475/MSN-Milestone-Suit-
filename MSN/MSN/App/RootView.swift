import SwiftUI

/// Shows setup until the library has a finished vault, then the main app.
struct RootView: View {

    @Environment(VaultSession.self) private var vault
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Group {
            if library.hasLibrary && vault.isSetupComplete {
                ContentView()
            } else {
                SetupView()
            }
        }
        .onChange(of: library.rootURL) { _, newRoot in
            vault.attach(to: newRoot)
        }
    }
}