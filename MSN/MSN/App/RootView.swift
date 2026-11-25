import SwiftUI

/// Shows first-launch setup until it is finished, then the main app.
struct RootView: View {

    @Environment(VaultSession.self) private var vault
    @AppStorage("setupComplete") private var setupComplete = false

    var body: some View {
        if setupComplete && vault.state != .needsSetup {
            ContentView()
        } else {
            SetupView(onFinish: { setupComplete = true })
        }
    }
}