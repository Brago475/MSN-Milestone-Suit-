import SwiftUI

/// Shows the launch screen, then setup until the library has a finished vault, then the main app.
struct RootView: View {

    @Environment(VaultSession.self) private var vault
    @Environment(LibraryStore.self) private var library
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if library.hasLibrary && vault.isSetupComplete {
                    ContentView()
                } else {
                    SetupView()
                }
            }

            if showSplash {
                SplashView(subtitle: library.hasLibrary ? "Opening \(library.libraryName)" : "Starting MSN")
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            appearance.apply()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1050))
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
        .onChange(of: library.rootURL) { _, newRoot in
            vault.attach(to: newRoot)
        }
    }
}