import SwiftUI

@main
struct MSNApp: App {

    init() {
        #if DEBUG
        VaultSelfTest.run()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
    }
}