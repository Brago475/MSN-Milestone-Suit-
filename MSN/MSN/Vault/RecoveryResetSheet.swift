import SwiftUI

/// Sets a new master password using the recovery key.
struct RecoveryResetSheet: View {

    @Environment(VaultSession.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var recoveryKey = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var keyLooksValid: Bool {
        RecoveryKey.normalize(recoveryKey) != nil
    }

    private var mismatch: Bool {
        !confirm.isEmpty && confirm != password
    }

    private var canReset: Bool {
        keyLooksValid && password.count >= 4 && password == confirm && !isWorking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Reset master password")
                    .font(.system(size: 20, weight: .bold))
                Text("Enter the recovery key you saved during setup, then choose a new password. Your files and secrets stay as they are.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Recovery key")
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $recoveryKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))
                    .controlSize(.large)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 6) {
                label("New password")
                SecureField("", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Confirm new password")
                SecureField("", text: $confirm)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                if mismatch {
                    Text("Passwords do not match.")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Spacer()
                if isWorking {
                    ProgressView().controlSize(.small)
                }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Reset password") {
                    Task { await reset() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canReset)
            }
        }
        .padding(28)
        .frame(width: 480)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func reset() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            try await vault.resetPassword(recoveryKey: recoveryKey, newPassword: password)
            dismiss()
        } catch {
            errorText = "That recovery key is not correct."
        }
    }
}