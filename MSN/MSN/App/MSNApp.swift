import SwiftUI

@main
struct MSNApp: App {

    @State private var vault = VaultSession()

    init() {
        #if DEBUG
        VaultSelfTest.run()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(vault)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
    }
}