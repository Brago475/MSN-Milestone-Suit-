import SwiftUI

/// First-launch flow: master password, recovery key, library folder.
struct SetupView: View {

    var onFinish: () -> Void

    @State private var step = 1
    @State private var recoveryKey = ""

    var body: some View {
        VStack(spacing: 22) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 84)

            SetupStepper(current: step)

            Group {
                if step == 1 {
                    PasswordStep { key in
                        recoveryKey = key
                        step = 2
                    }
                } else {
                    RecoveryStep(recoveryKey: recoveryKey, onContinue: onFinish)
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
    }
}

/// The numbered step indicator above the setup card.
struct SetupStepper: View {

    let current: Int
    private let titles = ["Master password", "Recovery key", "Library folder"]

    var body: some View {
        HStack(spacing: 22) {
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