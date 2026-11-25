import SwiftUI

/// Shown in the Secrets section while the vault is locked.
struct LockedView: View {

    @Environment(VaultSession.self) private var vault

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 18) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150)

            VStack(spacing: 6) {
                Text("Secrets are locked")
                    .font(.system(size: 22, weight: .bold))
                Text("Documents stay open. Unlock to see or copy secrets.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if vault.isTouchIDEnabled && vault.isTouchIDAvailable {
                Button {
                    Task { await unlockWithTouchID() }
                } label: {
                    Label("Unlock with Touch ID", systemImage: "touchid")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)

                HStack(spacing: 10) {
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                    Text("or")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                }
                .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Master password")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SecureField("Enter master password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .onSubmit { Task { await unlockWithPassword() } }
                    if isWorking {
                        ProgressView().controlSize(.small)
                    }
                }
                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 300)

            Text("Locks again after \(vault.autoLockMinutes) minutes away")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func unlockWithPassword() async {
        guard !password.isEmpty, !isWorking else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            try await vault.unlock(password: password)
            password = ""
        } catch {
            errorText = "That password is not correct."
        }
    }

    private func unlockWithTouchID() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            try await vault.unlockWithTouchID()
        } catch BiometricUnlock.BiometricError.cancelled {
            // Cancelled by the user. The password field stays available.
        } catch {
            errorText = "Touch ID could not unlock. Use your master password."
        }
    }
}