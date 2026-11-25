import SwiftUI

/// Setup step 1. Welcome and vault name.
struct WelcomeStep: View {

    @Binding var name: String
    var onContinue: () -> Void

    private var isValid: Bool {
        LibraryStore.isValidName(name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to MSN Milestone Suit")
                    .font(.system(size: 22, weight: .bold))
                Text("Everything you create lives in a vault: one folder that MSN manages for you. Your notes, secrets, diagrams and milestones all stay inside it. Start by giving it a name.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vault name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("My Vault", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .onSubmit { if isValid { onContinue() } }
                if !name.isEmpty && !isValid {
                    Text("Names can't start with a period or contain / or :.")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
    }
}