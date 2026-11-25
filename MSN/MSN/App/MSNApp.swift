import SwiftUI

@main
struct MSNApp: App {

    @State private var vault: VaultSession
    @State private var library: LibraryStore

    init() {
        FontRegistry.registerBundledFonts()

        #if DEBUG
        VaultSelfTest.run()
        #endif

        let library = LibraryStore()
        let vault = VaultSession()
        vault.attach(to: library.rootURL)
        _library = State(initialValue: library)
        _vault = State(initialValue: vault)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(vault)
                .environment(library)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)

        Settings {
            SettingsView()
        }
    }
}