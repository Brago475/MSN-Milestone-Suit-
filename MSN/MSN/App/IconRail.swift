import SwiftUI

struct IconRail: View {

    @Environment(VaultSession.self) private var vault
    @Environment(\.openSettings) private var openSettings
    @Binding var selection: AppSection

    private var isUnlocked: Bool {
        vault.state == .unlocked
    }

    var body: some View {
        VStack(spacing: 6) {
            Image("RailLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(.bottom, 6)
                .accessibilityLabel("MSN Milestone Suit")

            RailButton(section: .files, selection: $selection)
            RailDots()

            ForEach(AppSection.allCases.filter { $0 != .files }) { section in
                RailButton(section: section, selection: $selection)
            }

            Spacer()

            RailActionButton(
                symbol: isUnlocked ? "lock.open" : "lock.fill",
                title: isUnlocked ? "Lock secrets" : "Unlock secrets"
            ) {
                if isUnlocked {
                    vault.lock()
                } else {
                    selection = .secrets
                }
            }
            RailActionButton(symbol: "gearshape", title: "Settings") {
                openSettings()
            }
        }
        .padding(.top, Theme.titleBarInset)
        .padding(.bottom, 14)
        .frame(width: Theme.railWidth)
        .frame(maxHeight: .infinity)
        .background(.background.secondary)
    }
}

private struct RailButton: View {
    let section: AppSection
    @Binding var selection: AppSection

    var body: some View {
        let isSelected = selection == section

        Button {
            selection = section
        } label: {
            SectionIcon(section: section, size: 19)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: Theme.railButtonSize, height: Theme.railButtonSize)
                .background(
                    isSelected ? Theme.accent : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.railCornerRadius)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.railCornerRadius))
        }
        .buttonStyle(.plain)
        .help(section.title)
        .accessibilityLabel(section.title)
    }
}

private struct RailActionButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: Theme.railButtonSize, height: Theme.railButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct RailDots: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.secondary)
                    .frame(width: 3, height: 3)
            }
        }
        .padding(.vertical, 4)
    }
}