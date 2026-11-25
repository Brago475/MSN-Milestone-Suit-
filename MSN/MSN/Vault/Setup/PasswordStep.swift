import SwiftUI

/// Setup step 1. Creates the vault, or unlocks it if setup was left unfinished.
struct PasswordStep: View {

    @Environment(VaultSession.self) private var vault
    var onDone: (String) -> Void

    @State private var password = ""
    @State private var confirm = ""
    @State private var useTouchID = true
    @State private var isWorking = false
    @State private var errorText: String?

    private var isResuming: Bool {
        vault.state != .needsSetup
    }

    private var mismatch: Bool {
        !confirm.isEmpty && confirm != password
    }

    private var canContinue: Bool {
        if isResuming { return !password.isEmpty }
        return password.count >= 4 && password == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isResuming ? "Enter your master password" : "Create a master password")
                    .font(.system(size: 20, weight: .bold))
                Text(isResuming
                     ? "Setup was not finished. Enter the password you created to continue."
                     : "This password unlocks your secrets and locked folders. It can be simple, because it only works on this Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            field("Master password", text: $password)

            if !isResuming {
                field("Confirm password", text: $confirm)
                if mismatch {
                    Text("Passwords do not match.")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            if vault.isTouchIDAvailable {
                Toggle("Unlock with Touch ID", isOn: $useTouchID)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if isWorking {
                    ProgressView().controlSize(.small)
                }
                Button("Continue") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue || isWorking)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }

    private func submit() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            let key: String
            if isResuming {
                try await vault.unlock(password: password)
                key = try vault.makeNewRecoveryKey()
            } else {
                key = try await vault.createVault(password: password)
            }
            if useTouchID && vault.isTouchIDAvailable {
                try? vault.enableTouchID()
            }
            onDone(key)
        } catch {
            errorText = isResuming
                ? "That password is not correct."
                : "The vault could not be created. Try again."
        }
    }
}