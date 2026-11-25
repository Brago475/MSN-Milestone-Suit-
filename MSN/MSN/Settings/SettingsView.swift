import SwiftUI

/// The Settings window, opened with Command-comma or the gear in the rail.
struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 480)
    }
}

/// General settings: appearance.
struct GeneralSettings: View {

    @AppStorage("appearance") private var appearance: AppAppearance = .system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("System follows your Mac's light or dark setting.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: appearance) { _, newValue in
            newValue.apply()
        }
    }
}