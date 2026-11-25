import SwiftUI

/// Setup step 2. Placeholder until the full design is built.
struct RecoveryStep: View {

    let recoveryKey: String
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save your recovery key")
                .font(.system(size: 20, weight: .bold))
            Text(recoveryKey)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}