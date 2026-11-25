import SwiftUI

/// Setup step 2. Asks where the vault goes, then creates its folder.
struct LocationStep: View {

    @Environment(LibraryStore.self) private var library
    @Environment(VaultSession.self) private var vault

    let name: String
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var location: URL?
    @State private var didPrompt = false
    @State private var errorText: String?

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where should \(cleanName) live?")
                    .font(.system(size: 20, weight: .bold))
                Text("Choose a folder on your Mac. MSN will create your vault inside it. Documents is a good place to start, and iCloud Drive or an external drive also work.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Image(systemName: location == nil ? "folder.badge.questionmark" : "folder.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(location?.lastPathComponent ?? "No location chosen")
                        .font(.system(size: 13, weight: .semibold))
                    if let location {
                        Text(location.appendingPathComponent(cleanName).path(percentEncoded: false))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Suggested: Documents")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(location == nil ? "Choose Location…" : "Change…", action: pick)
            }
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Back", action: onBack)
                Button("Create Vault", action: create)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(location == nil)
            }
        }
        .onAppear {
            guard !didPrompt else { return }
            didPrompt = true
            DispatchQueue.main.async { pick() }
        }
    }

    private func pick() {
        if let url = VaultRegistry.chooseLocation(for: cleanName) {
            location = url
            errorText = nil
        }
    }

    private func create() {
        guard let location else { return }
        errorText = nil
        do {
            try library.createVault(named: cleanName, in: location)
            vault.attach(to: library.rootURL)
            onContinue()
        } catch {
            print("Vault folder error: \(error)")
            errorText = error.localizedDescription
        }
    }
}