import SwiftUI

/// First-launch flow: vault name, location, master password, recovery key.
struct SetupView: View {

    @Environment(VaultSession.self) private var vault
    @Environment(LibraryStore.self) private var library

    @State private var step = 1
    @State private var vaultName = ""
    @State private var recoveryKey = ""

    var body: some View {
        VStack(spacing: 22) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 84)

            SetupStepper(current: step)

            Group {
                switch step {
                case 1:
                    WelcomeStep(name: $vaultName) {
                        step = 2
                    }
                case 2:
                    LocationStep(
                        name: vaultName,
                        onBack: { step = 1 },
                        onContinue: { step = 3 }
                    )
                case 3:
                    PasswordStep { key in
                        recoveryKey = key
                        step = 4
                    }
                default:
                    RecoveryStep(recoveryKey: recoveryKey) {
                        try? vault.confirmRecoverySaved()
                    }
                }
            }
            .padding(28)
            .frame(width: 560)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.10), radius: 18, y: 12)
        }
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea()
        .onAppear {
            if library.hasLibrary {
                step = 3
            }
        }
    }
}

/// The numbered step indicator above the setup card.
struct SetupStepper: View {

    let current: Int
    private let titles = ["Vault name", "Location", "Master password", "Recovery key"]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                let number = index + 1
                let reached = number <= current
                HStack(spacing: 8) {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(reached ? Color.white : Color.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(reached ? Theme.accent : Color.secondary.opacity(0.15)))
                    Text(title)
                        .font(.system(size: 12, weight: number == current ? .semibold : .regular))
                        .foregroundStyle(number == current ? Color.primary : Color.secondary)
                }
            }
        }
    }
}